#!/usr/bin/env python3
"""客存单变量 A/B 的判读件：把多档取证并排摊开，回答「jetsam 缺页击杀有没有随客存消失」。

背景：49-data-mac-var 的 failed_process_exits 三条同形 `ns=1 sub=4`——
  ns=1 = OS_REASON_JETSAM（bsd/sys/reason.h:88）
  sub=4 = JETSAM_REASON_MEMORY_VMPAGESHORTAGE（bsd/sys/kern_memorystatus.h:294）
  生产者 = memorystatus_thread 的 MEMORYSTATUS_KILL_TOP_PROCESS（doc/vm/memorystatus_kills.md:17）
本机客存被钉死 1 GiB（run_umi_qemu.py 写死 --qemu-memory-mib 1024 与 --dram-size 0x40000000），
而真机 umi 有 8 GiB。所以假设是「客存不够 → 内核 jetsam 杀服务」，不是服务自己有毛病。
本件配合 tools-wsl/make-run-umi-qemu-guest-ram.py 做单变量对照。

三条几何必须同读，否则「抬了没抬」说不清：
  ADT /chosen/dram-size（内核 osfmk/arm64/sptm/arm_init_sptm.c:888 读它得 gDramSize）
  gdb-stop.json 的 qemu_memory_mib（QEMU 实际 -m）
  内核活体全局 _gDramSize（内核自己以为有多少 RAM）

环形缓冲的深度限制摆在明面上：recent[4]/failures[3] 只留最近几发，
所以「这一档的失败环里没有 ns=1」是有力线索而不是全量计数——总量看 process_exit_counts。

用法：evaluate-jetsam-ram-ab.py RUN1 RUN2 ... [--root WS] [--kernel NAME.macho]
"""
import argparse
import json
import re
import struct
import subprocess
import sys
from pathlib import Path

DEFAULT_ROOT = Path("/home/unixnu/code/umi-work-pin")
RECORD = re.compile(r"^p(?P<pid>\d+)\s+(?P<name>\S+)\s+status=(?P<status>\d+)\s+sig=(?P<sig>\d+)\s+"
                    r"exit=(?P<exit>\d+)\s+ns=(?P<ns>\d+)\s+sub=(?P<sub>\d+)")
NAMESPACE = {0: "无 reason", 1: "JETSAM", 2: "SIGNAL", 3: "CODESIGNING", 6: "DYLD", 9: "EXEC",
             10: "SPRINGBOARD", 15: "RUNNINGBOARD", 20: "WATCHDOG", 25: "SANDBOX", 36: "BOOTMOUNT"}
JETSAM_CODE = {1: "GENERIC", 2: "MEMORY_HIGHWATER", 3: "VNODE", 4: "MEMORY_VMPAGESHORTAGE",
               5: "MEMORY_PROCTHRASHING", 6: "MEMORY_FCTHRASHING", 7: "MEMORY_PERPROCESSLIMIT",
               8: "MEMORY_DISK_SPACE_SHORTAGE", 9: "MEMORY_IDLE_EXIT", 10: "ZONE_MAP_EXHAUSTION",
               11: "VMCOMPRESSOR_THRASHING", 12: "VMCOMPRESSOR_SPACE_SHORTAGE", 13: "LOWSWAP",
               14: "SUSTAINED_PRESSURE", 15: "VMPAGEOUT_STARVATION", 100: "CPULIMIT"}
# struct bp_exits 的字段偏移（官方 analyze_umi_systemos_qemu.py 无条件读的那 2382 字节同一布局）
EXIT_TOTAL_LEN = 2382
RECENT_OFF, RECENT_N, SLOT = 12, 4, 120
FAILED_OFF, FAILED_N = 492, 3


def symbols(kernel):
    out = subprocess.run(["xcrun", "nm", "-n", str(kernel)], capture_output=True, text=True).stdout
    if not out.strip():
        raise SystemExit(f"nm 读不到 {kernel}——先导出 XNU_TOOLCHAIN_BIN 与工具链 PATH")
    table = {}
    for line in out.splitlines():
        parts = line.split()
        if len(parts) == 3:
            table.setdefault(parts[2], int(parts[0], 16))
    return table


class Run:
    def __init__(self, root, name, table):
        self.name = name
        run = root / "out/umi-qemu" / name
        self.stop = json.loads((run / "gdb-stop.json").read_text())
        self.memory = self.stop.get("memory", {})
        self.table = table
        self.counts = None
        self.recs = []
        key = f"{table['_exit_records']:#x}:{EXIT_TOTAL_LEN:x}"
        if key in self.memory:
            blob = bytes.fromhex(self.memory[key])
            self.counts = list(struct.unpack_from("<3I", blob))
            self.recs = self.records(blob)
        adt = run / "esp/EFI/UniXNU/Payloads/kernel.macho.adt"
        self.adt_dram = self.dram_from_adt(adt) if adt.exists() else None

    @staticmethod
    def dram_from_adt(path):
        sys.path.insert(0, str(ROOT / "devices/umi/scripts"))
        from umi_adt import decode
        props = decode(path.read_bytes()).at("/chosen").properties
        return struct.unpack("<Q", props["dram-size"])[0]

    def value(self, name, size):
        key = f"{self.table['_' + name]:#x}:{size:x}"
        return int.from_bytes(bytes.fromhex(self.memory[key]), "little") if key in self.memory else None

    def records(self, blob):
        found = []
        for off, count, slot in ((RECENT_OFF, RECENT_N, "recent"), (FAILED_OFF, FAILED_N, "failed")):
            for i in range(count):
                text = blob[off + i * SLOT:off + (i + 1) * SLOT].split(b"\0", 1)[0].decode(errors="replace")
                match = RECORD.match(text)
                if match:
                    found.append((slot, match.groupdict(), text))
        return found

    @property
    def jetsam(self):
        return [r for r in self.recs if r[1]["ns"] == "1"]


def mib(bytes_value):
    return f"{bytes_value // 1024**2} MiB" if isinstance(bytes_value, int) else "缺"


def main():
    global ROOT
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("runs", nargs="+", help="out/umi-qemu/ 下的档名")
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT, help="umi-work-pin 工作区")
    parser.add_argument("--kernel", default="qemu-systemos-data-mac64.macho",
                        help="判读用的内核名（out/umi-xnu/umi/kernel/ 下）")
    args = parser.parse_args()
    ROOT = args.root
    table = symbols(ROOT / "out/umi-xnu/umi/kernel" / args.kernel)
    parsed = [Run(ROOT, name, table) for name in args.runs]
    width = max(len(r.name) for r in parsed)

    print("== 1. 客存几何三处（内核只吃 ADT 的 dram-size；三处必须一致）==")
    for r in parsed:
        live = r.value("gDramSize", 8)
        qemu = r.stop.get("qemu_memory_mib")
        ok = r.adt_dram and qemu and live and r.adt_dram == qemu * 1024**2 == live
        print(f"  {r.name:<{width}}  ADT={mib(r.adt_dram):<9} QEMU -m={str(qemu) + ' MiB' if qemu else '缺':<9} "
              f"内核 _gDramSize={mib(live):<9} 三处一致={'PASS' if ok else '不符/缺读'}"
              f"   dram-base={hex(r.value('gDramBase', 8) or 0)}")

    print("\n== 2. 进程退出面 ==")
    for r in parsed:
        seen = r.value("umi_exec_trace_seen", 8)
        print(f"  {r.name:<{width}}  counts(总,非0,崩)={r.counts}  "
              f"Data(状态,段,只读)={[r.value(n, 4) for n in ('native_owner_data_status', 'native_owner_data_stage', 'native_owner_data_readonly')]}  "
              f"RAM块(读,写)={[r.value(n, 8) for n in ('native_ram_block_reads', 'native_ram_block_writes')]}  "
              f"initproc={r.value('initproc_spawned', 4)}  panic位={'是' if seen and seen & (1 << 5) else '否'}")

    print("\n== 3. 环内记录按 exit reason 归类（recent[4]+failures[3]，环浅只作线索）==")
    for r in parsed:
        print(f"  {r.name:<{width}}  环内 {len(r.recs)} 发，其中 JETSAM {len(r.jetsam)} 发")
        for slot, d, text in r.jetsam:
            print(f"      [{slot:<6}] {text}  -> {NAMESPACE[1]} / "
                  f"{JETSAM_CODE.get(int(d['sub']), '未知 code ' + d['sub'])}")
        for slot, d, text in r.recs:
            if d["ns"] != "1":
                print(f"      [{slot:<6}] {text}  -> {NAMESPACE.get(int(d['ns']), '命名空间 ' + d['ns'])}")

    print("\n== 4. 结论口径 ==")
    base, *rest = parsed
    for r in rest:
        if len(r.jetsam) < len(base.jetsam):
            verdict = "减少，支持「客存不够 → jetsam 杀服务」"
        elif len(r.jetsam) > len(base.jetsam):
            verdict = "反而增加，客存不是唯一因（或这一趟时序本身有抖动）"
        else:
            verdict = "没变，客存这条假设被这一档否掉"
        print(f"  {r.name} 相对基线 {base.name}：环内 JETSAM {len(base.jetsam)} -> {len(r.jetsam)}（{verdict}）")

    print("\n== 5. 停点 ==")
    for r in parsed:
        print(f"  {r.name:<{width}}  pc={r.stop.get('pc')}  超时停={r.stop.get('bounded_timeout_interrupted')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
