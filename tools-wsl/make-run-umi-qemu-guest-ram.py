#!/usr/bin/env python3
"""给本机真正被执行的 run_umi_qemu.py 加两条「内存几何」旋钮：
  UMI_GUEST_RAM_MIB      -> QEMU 的 -m 与 ADT 的 /chosen/dram-size（两者必须同动）
  UMI_OWNED_MEMORY_MIB   -> ADT 的 /chosen/darwinboot-memory-size，也就是 darwinboot
                            真正交给 XNU 的那块内存

为什么要第二条旋钮（本仓实测，客存那条已被否掉）：
  50/51 两档把 dram-size 从 1 GiB 抬到 2 GiB，屏上 MEM 行仍是 `totalMiB=320`、
  `free min/reserved/target=267/128/4017` 逐字相同——jetsam 的百分比门槛按
  MEMSTAT_PERCENT_TOTAL_PAGES 算的是 max_mem，而 max_mem 来自 args->memSize
  （osfmk/arm64/sptm/arm_init_sptm.c:1551 `gPhysSize = mem_size = ...args->memSize`、
  :1745 `max_mem = mem_size`），不是 ADT 的 dram-size。args->memSize 就是
  darwinboot-memory-size，本机由 run_umi_qemu.py 的 --owned-memory-mib 320 钉死。
  所以「内核以为自己能用的 RAM」= owned 区，抬客存抬不动它。

上游把 --owned-memory-mib 的 choices 写死 (256,320,512)；make-dt.py 自己的硬闸是
0x10000000..0x100000000 且 2 MiB 对齐（scripts/qemu-entry/make-dt.py:42），比它宽得多。
本段只把 argparse 的那道窄闸换成 env + make-dt 同款的宽闸校验，默认值仍是上游的 256，
所以不设环境变量时产出的 ADT 与改动前逐字节相同。

两个旋钮都不设时（1024 / 256）几何与上游一致——同一份替换既能当实验件也能当对照件。
上游观测件本体其它地方一字不改，判读件也不改。

用法：make-run-umi-qemu-guest-ram.py [--runner PATH] [--restore]
"""
import argparse
import hashlib
import os
import sys
from pathlib import Path

DEFAULT_RUNNER = Path("/home/unixnu/code/umi-work-pin/tools/run_umi_qemu.py")
MARKER = "UMI_GUEST_RAM"
OWNED_MARKER = "UMI_OWNED_MEMORY_MIB"
GUEST_CHOICES = (512, 1024, 2048, 4096, 8192)

ARG_ANCHOR = ('    p.add_argument("--owned-memory-mib", choices=(256,320,512), type=int, default=256)\n',
              '    p.add_argument("--owned-memory-mib", type=int, default=OWNED_MEMORY_MIB)\n')
ANCHORS = [
    ("import json\nfrom pathlib import Path\n",
     "import json\nimport os\nfrom pathlib import Path\n"),
    ('        "--owned-memory-size", hex(a.owned_memory_mib << 20), "--dram-size", "0x40000000",\n',
     '        "--owned-memory-size", hex(a.owned_memory_mib << 20), "--dram-size", hex(GUEST_RAM_MIB << 20),\n'),
    ('               "--qemu-memory-mib", "1024", "--gic-version", "3",\n',
     '               "--qemu-memory-mib", str(GUEST_RAM_MIB), "--gic-version", "3",\n'),
    ARG_ANCHOR,
]

DEF_BLOCK = (
    "# " + MARKER + ": one knob for both the QEMU -m size and the ADT /chosen/dram-size that\n"
    "# arm64 XNU reads into gDramSize. The two must move together or the kernel maps RAM\n"
    "# QEMU did not provide. Default 1024 keeps the upstream geometry byte-identical.\n"
    "GUEST_RAM_MIB = int(os.environ.get(\"" + MARKER + "_MIB\", \"1024\"))\n"
    "assert GUEST_RAM_MIB in " + repr(GUEST_CHOICES) + ", GUEST_RAM_MIB\n"
    "# " + OWNED_MARKER + ": the ADT darwinboot-memory-size, i.e. the region darwinboot hands\n"
    "# XNU as args->memSize. arm_init_sptm.c turns that into max_mem, and max_mem -- not\n"
    "# dram-size -- is what jetsam thresholds and vm_page_free_* are computed against.\n"
    "# Upstream argparse allowed only 256/320/512; make-dt.py:42 allows 256 MiB..4 GiB at\n"
    "# 2 MiB alignment, which is the gate reproduced here. Default 256 is upstream's.\n"
    "OWNED_MEMORY_MIB = int(os.environ.get(\"" + OWNED_MARKER + "\", \"256\"))\n"
    "assert 256 <= OWNED_MEMORY_MIB <= 4096 and OWNED_MEMORY_MIB % 2 == 0, OWNED_MEMORY_MIB\n"
)
DEF_ANCHOR = 'UPSTREAM = ROOT / "sources/UniXNU"\n'

# 上一版只有 dram-size/-m 这一条旋钮，它的定义块正好是本段 DEF_BLOCK 的前五行——
# 所以撤补丁时必须先试长的再试短的，反过来会把 owned 那半截留在文件里。
LEGACY_DEF_BLOCK = (
    "# " + MARKER + ": one knob for both the QEMU -m size and the ADT /chosen/dram-size that\n"
    "# arm64 XNU reads into gDramSize. The two must move together or the kernel maps RAM\n"
    "# QEMU did not provide. Default 1024 keeps the upstream geometry byte-identical.\n"
    "GUEST_RAM_MIB = int(os.environ.get(\"" + MARKER + "_MIB\", \"1024\"))\n"
    "assert GUEST_RAM_MIB in " + repr(GUEST_CHOICES) + ", GUEST_RAM_MIB\n"
)


def apply(content):
    for before, after in ANCHORS:
        if content.count(before) != 1:
            raise SystemExit(f"锚点 {before.strip()!r} 命中 {content.count(before)} 次，停手")
        content = content.replace(before, after, 1)
    if content.count(DEF_ANCHOR) != 1:
        raise SystemExit(f"锚点 {DEF_ANCHOR.strip()!r} 命中 {content.count(DEF_ANCHOR)} 次，停手")
    return content.replace(DEF_ANCHOR, DEF_ANCHOR + DEF_BLOCK, 1)


def restore(content):
    removed = None
    for block in (DEF_BLOCK, LEGACY_DEF_BLOCK):
        if block in content:
            removed = block
            break
    if removed is None:
        raise SystemExit(f"看不到 {MARKER} 定义块，原件可能已被别的改动覆盖，停手")
    content = content.replace(removed, "", 1)
    for before, after in ANCHORS:
        # 旧版没动过 owned-memory-mib 那条 argparse，撤旧版补丁时它是「本来就没打过」的样子。
        if content.count(after) == 1:
            content = content.replace(after, before, 1)
        elif content.count(before) == 1:
            continue
        else:
            raise SystemExit(f"锚点 {after.strip()!r} 命中 {content.count(after)} 次，停手")
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
    elif DEF_BLOCK in original:
        print(f"runner={args.runner} 已应用 sha256={before_sha}")
        return 0
    elif MARKER in original:
        raise SystemExit(f"runner={args.runner} 上有旧版 {MARKER} 补丁（定义块不同），"
                         "先 --restore 再重打，别叠")
    else:
        content = apply(original)

    compile(content, str(args.runner), "exec")
    args.runner.write_text(content)
    print(f"runner={args.runner} {'已撤销' if args.restore else '已应用'} sha256 "
          f"{before_sha[:16]} -> {hashlib.sha256(args.runner.read_bytes()).hexdigest()[:16]}")
    print(f"  本进程环境里的 {MARKER}_MIB = {os.environ.get(MARKER + '_MIB', '（未设，取默认 1024）')}")
    print(f"  本进程环境里的 {OWNED_MARKER} = {os.environ.get(OWNED_MARKER, '（未设，取上游默认 256）')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
