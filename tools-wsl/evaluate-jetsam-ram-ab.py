#!/usr/bin/env python3
"""内存几何单变量 A/B 的判读件：把多档取证并排摊开，回答「jetsam 缺页击杀有没有随可用内存消失」。

背景：49-data-mac-var 的 failed_process_exits 三条同形 `ns=1 sub=4`——
  ns=1 = OS_REASON_JETSAM（bsd/sys/reason.h:88）
  sub=4 = JETSAM_REASON_MEMORY_VMPAGESHORTAGE（bsd/sys/kern_memorystatus.h:294）
  生产者 = memorystatus_thread 的 MEMORYSTATUS_KILL_TOP_PROCESS（doc/vm/memorystatus_kills.md:17）
本机客存被钉死 1 GiB（run_umi_qemu.py 写死 --qemu-memory-mib 1024 与 --dram-size 0x40000000），
而真机 umi 有 8 GiB。50/51 两档把客存抬到 2 GiB 之后 jetsam 照旧——**这条假设已否**：
内核可用池按 max_mem 算，而 max_mem 来自 args->memSize（ADT darwinboot-memory-size，
本机 --owned-memory-mib 320），不是 dram-size。所以真旋钮是 owned，判读件两档都要读四处。

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
PAGE = 4096  # native 4K；仪表读到的全是「页数」，换算成 MiB 才看得出压力量级


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
        self.chosen = self.adt_chosen(adt) if adt.exists() else {}
        self.adt_dram = struct.unpack("<Q", self.chosen["dram-size"])[0] if self.chosen else None
        # darwinboot-memory-size 才是 args->memSize 的出处（arm_init_sptm.c:1551 → max_mem），
        # dram-size 只决定 QEMU 给了多少 RAM、内核以为自己有多少（gDramSize）。
        self.adt_owned = (struct.unpack("<Q", self.chosen["darwinboot-memory-size"])[0]
                          if "darwinboot-memory-size" in self.chosen else None)

    @staticmethod
    def adt_chosen(path):
        sys.path.insert(0, str(ROOT / "devices/umi/scripts"))
        from umi_adt import decode
        return decode(path.read_bytes()).at("/chosen").properties

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

    print("== 1. 内存几何四处（客存/owned/内核可用池；owned 那条才是 max_mem 的出处）==")
    for r in parsed:
        live = r.value("gDramSize", 8)
        qemu = r.stop.get("qemu_memory_mib")
        ok = r.adt_dram and qemu and live and r.adt_dram == qemu * 1024**2 == live
        print(f"  {r.name:<{width}}  ADT dram={mib(r.adt_dram):<9} QEMU -m={str(qemu) + ' MiB' if qemu else '缺':<9} "
              f"_gDramSize={mib(live):<9} 三处一致={'PASS' if ok else '不符/缺读'}")
        print(f"      ADT darwinboot-memory-size={mib(r.adt_owned):<9} "
              f"_max_mem={mib(r.value('max_mem', 8)):<9} _mem_size={mib(r.value('mem_size', 8)):<9} "
              f"_sane_size={mib(r.value('sane_size', 8)):<9} _gPhysSize={mib(r.value('gPhysSize', 8))}"
              f"   （屏上 MEM totalMiB 就是 _max_mem>>20）")

    def mb(pages):
        return f"{pages * PAGE // 1024 ** 2} MiB" if isinstance(pages, int) else "缺"

    print("\n== 1.5 jetsam 触发判据本体（kern_memorystatus.c:3652 就是 available <= critical 这一条比较）==")
    for r in parsed:
        avail = r.value("memorystatus_available_pages", 4)
        crit = r.value("memorystatus_available_pages_critical", 4)
        if avail is None or crit is None:
            print(f"  {r.name:<{width}}  本档没读这批仪表（要带 memorystatus_* 读址集的档，52/53）")
            continue
        print(f"  {r.name:<{width}}  available={mb(avail)} critical={mb(crit)} "
              f"level={r.value('memorystatus_level', 4)}%  ->  低于临界={'是（该杀）' if avail <= crit else '否'}")
        print(f"      三条门槛：base={mb(r.value('memorystatus_available_pages_critical_base', 4))} "
              f"idle={mb(r.value('memorystatus_available_pages_critical_idle', 4))} "
              f"pressure={mb(r.value('memorystatus_available_pages_pressure', 4))}  "
              f"vm_pressure_level={r.value('memorystatus_vm_pressure_level', 4)} "
              f"compressor_shortage={r.value('memorystatus_compressor_space_shortage', 4)}")
        print(f"      页：free={mb(r.value('vm_page_free_count', 4))}/target={mb(r.value('vm_page_free_target', 4))}"
              f"/min={mb(r.value('vm_page_free_min', 4))}  wire={mb(r.value('vm_page_wire_count', 4))} "
              f"pageable_internal={mb(r.value('vm_page_pageable_internal_count', 4))} "
              f"speculative={mb(r.value('vm_page_speculative_count', 4))}")

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

    def below_critical(r):
        a, c = r.value("memorystatus_available_pages", 4), r.value("memorystatus_available_pages_critical", 4)
        return None if a is None or c is None else (a <= c)

    for r in rest:
        if len(r.jetsam) < len(base.jetsam):
            verdict = "减少，支持「内核可用池不够 → jetsam 杀服务」"
        elif len(r.jetsam) > len(base.jetsam):
            verdict = "反而增加，可用池不是唯一因（或这一趟时序本身有抖动）"
        else:
            verdict = "没变，这一档没打掉它"
        print(f"  {r.name} 相对基线 {base.name}：环内 JETSAM {len(base.jetsam)} -> {len(r.jetsam)}（{verdict}）")
        b0, b1 = below_critical(base), below_critical(r)
        if b0 is not None and b1 is not None:
            gate = "触发判据成立" if b0 and not b1 else ("判据两边都成立" if b0 and b1 else "判据两边都不成立")
            print(f"      available<=critical：{base.name}={b0} -> {r.name}={b1}（{gate}）")

    print("\n== 5. 停点 ==")
    for r in parsed:
        print(f"  {r.name:<{width}}  pc={r.stop.get('pc')}  超时停={r.stop.get('bounded_timeout_interrupted')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
