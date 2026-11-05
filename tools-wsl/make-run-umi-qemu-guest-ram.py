#!/usr/bin/env python3
"""给本机真正被执行的 run_umi_qemu.py 加一条「客存可配」替换：让 QEMU 的 -m 与 ADT 的
/chosen/dram-size 由同一个环境变量 UMI_GUEST_RAM_MIB 决定。

为什么动这一件：49-data-mac-var 里 configd/fseventsd/containermanagerd_system 三条同形
SIGKILL（ns=1 sub=4）解出来是 OS_REASON_JETSAM + JETSAM_REASON_MEMORY_VMPAGESHORTAGE
（bsd/sys/reason.h:88 + bsd/sys/kern_memorystatus.h:294），上游自己的归因表
doc/vm/memorystatus_kills.md:17 把这条 code 的生产者钉在 memorystatus_thread 的
MEMORYSTATUS_KILL_TOP_PROCESS 上——是内核 jetsam 缺页击杀，不是这些服务自己有毛病。
而本机客存被钉死在 1 GiB：run_umi_qemu.py:257 把 --dram-size 写死 0x40000000、
:283 把 --qemu-memory-mib 写死 "1024"，实测 49 档的 kernel.macho.adt 里
dram-base=dram-size=1073741824。真机 umi 有 8 GiB，上游别的机型（alioth）ADT 就是 0x200000000。

两个旋钮必须一起动，否则会脱钩：arm64 XNU 只读 ADT 的 /chosen/dram-size 得到 gDramSize
（osfmk/arm64/sptm/arm_init_sptm.c:888-893），QEMU 那边没有 -dtb（gdb-stop.py 只喂 pflash），
所以 -m 决定「实际有多少 RAM」、dram-size 决定「内核以为有多少」。上游
scripts/probe-darwinboot-xnu.py:327 已经是这个耦合写法（--dram-size = qemu_memory_mib*1024**2）。
QEMU virt 在 2048/4096 MiB 下 RAM 仍是 0x40000000 起的单段连续 bank（实测 dumpdtb：
reg=<0 0x40000000 0 0x80000000> / <0 0x40000000 1 0x00>），不存在断开问题。

不设 UMI_GUEST_RAM_MIB 时默认 1024，几何与改动前逐字节相同——所以同一份替换既能当实验件、
也能当对照组（50 档显式给 1024）。上游观测件本体与判读件都不改。

用法：make-run-umi-qemu-guest-ram.py [--runner PATH] [--restore]
"""
import argparse
import hashlib
import os
import sys
from pathlib import Path

DEFAULT_RUNNER = Path("/home/unixnu/code/umi-work-pin/tools/run_umi_qemu.py")
MARKER = "UMI_GUEST_RAM"
CHOICES = (512, 1024, 2048, 4096, 8192)

ANCHORS = [
    ("import json\nfrom pathlib import Path\n",
     "import json\nimport os\nfrom pathlib import Path\n"),
    ('        "--owned-memory-size", hex(a.owned_memory_mib << 20), "--dram-size", "0x40000000",\n',
     '        "--owned-memory-size", hex(a.owned_memory_mib << 20), "--dram-size", hex(GUEST_RAM_MIB << 20),\n'),
    ('               "--qemu-memory-mib", "1024", "--gic-version", "3",\n',
     '               "--qemu-memory-mib", str(GUEST_RAM_MIB), "--gic-version", "3",\n'),
]

DEF_BLOCK = (f'# {MARKER}: one knob for both the QEMU -m size and the ADT /chosen/dram-size that\n'
             '# arm64 XNU reads into gDramSize. The two must move together or the kernel maps RAM\n'
             '# QEMU did not provide. Default 1024 keeps the upstream geometry byte-identical.\n'
             f'GUEST_RAM_MIB = int(os.environ.get("{MARKER}_MIB", "1024"))\n'
             f'assert GUEST_RAM_MIB in {CHOICES}, GUEST_RAM_MIB\n')
DEF_ANCHOR = 'UPSTREAM = ROOT / "sources/UniXNU"\n'


def apply(content):
    for before, after in ANCHORS:
        if content.count(before) != 1:
            raise SystemExit(f"锚点 {before.strip()!r} 命中 {content.count(before)} 次，停手")
        content = content.replace(before, after, 1)
    if content.count(DEF_ANCHOR) != 1:
        raise SystemExit(f"锚点 {DEF_ANCHOR.strip()!r} 命中 {content.count(DEF_ANCHOR)} 次，停手")
    return content.replace(DEF_ANCHOR, DEF_ANCHOR + DEF_BLOCK, 1)


def restore(content):
    if DEF_BLOCK not in content:
        raise SystemExit(f"看不到 {MARKER} 定义块，原件可能已被别的改动覆盖，停手")
    content = content.replace(DEF_BLOCK, "", 1)
    for before, after in ANCHORS:
        if content.count(after) != 1:
            raise SystemExit(f"反查锚点 {after.strip()!r} 命中 {content.count(after)} 次，停手")
        content = content.replace(after, before, 1)
    return content


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runner", type=Path, default=DEFAULT_RUNNER,
                        help="本机真正被执行的那份 run_umi_qemu.py")
    parser.add_argument("--restore", action="store_true", help="撤掉本段替换，回到未打补丁的原件")
    args = parser.parse_args()

    original = args.runner.read_text()
    before_sha = hashlib.sha256(args.runner.read_bytes()).hexdigest()

    if args.restore:
        if MARKER not in original:
            print(f"runner={args.runner} 本来就没打过本段补丁，无需撤")
            return 0
        content = restore(original)
    elif MARKER in original:
        print(f"runner={args.runner} 已应用 sha256={before_sha}")
        return 0
    else:
        content = apply(original)

    compile(content, str(args.runner), "exec")
    args.runner.write_text(content)
    print(f"runner={args.runner} {'已撤销' if args.restore else '已应用'} sha256 "
          f"{before_sha[:16]} -> {hashlib.sha256(args.runner.read_bytes()).hexdigest()[:16]}")
    print(f"  本进程环境里的 {MARKER}_MIB = {os.environ.get(MARKER + '_MIB', '（未设，取默认 1024）')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
