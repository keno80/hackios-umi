#!/bin/bash
# 确认：defconfig->env 的接线、build_umi_xnu 是否会自动产 mockfs fixture、两份 umi 仓的关系
set -u
OUT=/mnt/e/Code/HackIos/out/probes/mockfs-wiring2.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
WS=/home/unixnu/code/umi-work-pin
T=$WS/out/umi-xnu/umi/tree

say "== 1. build_umi_xnu.py 里 mockfs / defconfig 的接线 =="
grep -n 'mockfs\|MOCKFS' "$WS/tools/build_umi_xnu.py" >> "$OUT" 2>&1
say "-- 该脚本是否存在 --"
ls -l "$WS/tools/build_umi_xnu.py" >> "$OUT" 2>&1
say "-- defconfig 解析点 --"
grep -n 'defconfig' "$WS/tools/build_umi_xnu.py" >> "$OUT" 2>&1
head -60 "$WS/tools/build_umi_xnu.py" >> "$OUT" 2>&1

say
say "== 2. 谁调用 build-mockfs-fixture.py（全 WSL 代码）=="
grep -rn 'build-mockfs-fixture' "$WS" /home/unixnu/code/UniXNU-main 2>/dev/null | grep -v '\.git/' | head -20 >> "$OUT"

say
say "== 3. 两份 umi 设备仓关系 =="
for R in /home/unixnu/code/UniXNU-umi /home/unixnu/code/umi-work-pin/devices/umi /mnt/e/Code/HackIos/UniXNU-umi; do
  say "-- $R --"
  git -C "$R" remote -v 2>&1 | head -2 >> "$OUT"
  git -C "$R" log --oneline -3 2>&1 >> "$OUT"
  git -C "$R" status --porcelain 2>&1 | head -8 >> "$OUT"
  grep -n 'SOURCE_MOCKFS' "$R/configs/umi_defconfig" 2>&1 >> "$OUT"
done

say
say "== 4. 现成 kernel 产物与 mockfs 符号 =="
K=$(ls -1t "$T/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837"/mach.development.bcm2837.unstripped* 2>/dev/null | head -3)
say "$K"
for f in $K; do say "-- $f --"; /opt/unixnu-linux/llvm/bin/llvm-nm "$f" 2>/dev/null | grep -i mockfs | head -5 >> "$OUT"; done
say "-- vfs_conf.o 是否已含 mockfs 符号 --"
/opt/unixnu-linux/llvm/bin/llvm-nm "$T/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/bsd/DEVELOPMENT/vfs_conf.o" 2>/dev/null | grep -i mockfs | head -5 >> "$OUT"
say "-- .source-mockfs-mode stamp --"
cat "$T/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/bsd/DEVELOPMENT/.source-mockfs-mode" 2>&1 >> "$OUT"
say done
