#!/bin/bash
# 定位 umi 设备仓在 WSL 构建树中的真实可编辑路径，以及 mockfs 开关的读取点
set -u
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
OUT=/mnt/e/Code/HackIos/out/umi-device-repo-path.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }

say "== 1. tree 顶层（找 devices / 设备仓副本）=="
ls -1 "$T" >> "$OUT" 2>&1
say "-- 全树里名为 umi_defconfig 的文件 --"
find "$T" -maxdepth 6 -name 'umi_defconfig' -printf '%p\t%TY-%Tm-%Td %TH:%TM\t%s\n' 2>/dev/null >> "$OUT"
say "-- 全树里名为 board.toml 的文件 --"
find "$T" -maxdepth 6 -name 'board.toml' -printf '%p\t%s\n' 2>/dev/null >> "$OUT"
say "-- devices 目录（任意深度<=4）--"
find "$T" -maxdepth 4 -type d -name 'umi' -printf '%p -> %l\n' 2>/dev/null >> "$OUT"

say
say "== 2. 谁读 umi_defconfig / CONFIG_XNU_SOURCE_MOCKFS =="
grep -rn 'umi_defconfig' "$T/scripts" 2>/dev/null | head -20 >> "$OUT"
say "-- SOURCE_MOCKFS 在读配置/门禁里的位置 --"
grep -rn 'SOURCE_MOCKFS' "$T/scripts" 2>/dev/null | head -30 >> "$OUT"
say "-- 设备仓配置解析器（defconfig -> env）--"
grep -rln 'defconfig' "$T/scripts" 2>/dev/null | head -25 >> "$OUT"

say
say "== 3. mockfs fixture 构建脚本全文头部 =="
sed -n '1,80p' "$T/scripts/build-mockfs-fixture.py" >> "$OUT" 2>&1

say
say "== 4. baseline 里 MOCKFS 相关段（上下文 20 行）=="
grep -n 'MOCKFS' "$T/scripts/build-xnu-4k-baseline.sh" >> "$OUT" 2>&1
say "-- 240..275 --"
sed -n '240,275p' "$T/scripts/build-xnu-4k-baseline.sh" >> "$OUT" 2>&1
say "-- 750..790 --"
sed -n '750,790p' "$T/scripts/build-xnu-4k-baseline.sh" >> "$OUT" 2>&1

say
say "== 5. umi 设备仓在 windows 侧（E:）是否为 git 工作树 / 与树内副本关系 =="
cd /mnt/e/Code/HackIos/UniXNU-umi 2>/dev/null && {
  say "-- board.toml [kernel] 段 --"
  sed -n '/^\[kernel\]/,/^\[[a-z]/p' board.toml >> "$OUT" 2>&1
  say "-- configs/umi_defconfig 里 MOCKFS/ARMCPU/PTHREAD 行 --"
  grep -n 'MOCKFS\|ARMCPU\|PTHREAD\|LD_ARCHIVES' configs/umi_defconfig >> "$OUT" 2>&1
  say "-- patches 目录 --"
  ls -1 patches >> "$OUT" 2>&1
  ls -1 patches/umi-xnu 2>/dev/null | head -40 >> "$OUT"
}
say done
