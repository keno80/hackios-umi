#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/mockfs-legacy-root.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
S=/home/unixnu/code/UniXNU-main

say "== 1. mockfs_fsnode.c: size / backing_offset 的来源 =="
sed -n '55,130p' "$X/bsd/miscfs/mockfs/mockfs_fsnode.c" >> "$OUT" 2>&1

say
say "== 2. mockfs_vfsops.c: N4KROOT 之后的建根段（legacy 模式剩下什么）=="
sed -n '160,240p' "$X/bsd/miscfs/mockfs/mockfs_vfsops.c" >> "$OUT" 2>&1

say
say "== 3. DarwinBoot 侧 initrd -> RAMDisk 的填写 =="
grep -rn 'initrd\|Initrd\|RAMDisk' "$S/drivers/DarwinBoot/DarwinBootPkg/Driver/DarwinBoot.c" 2>/dev/null | head -30 >> "$OUT"
say "-- 其他 DarwinBoot 文件 --"
grep -rln 'RAMDisk' "$S/drivers" 2>/dev/null | head -10 >> "$OUT"

say
say "== 4. probe-darwinboot-xnu.py:345-360（--ramdisk 传参上下文）=="
sed -n '340,360p' "$S/scripts/probe-darwinboot-xnu.py" >> "$OUT" 2>&1

say
say "== 5. 仓里所有提到 mockfs 的脚本/配置 =="
grep -rln 'mockfs' "$S/scripts" "$S/devices" /home/unixnu/code/umi-work-pin/tools 2>/dev/null | head -20 >> "$OUT"

say
say "== 6. make-dt.py 的 --ramdisk 分支 =="
sed -n '90,120p' "$S/scripts/qemu-entry/make-dt.py" >> "$OUT" 2>&1
say done
