#!/bin/bash
# 找 umi_defconfig/board.toml 的真实位置 + defconfig->env 解析器 + mockfs 前置件是否齐
set -u
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
OUT=/mnt/e/Code/HackIos/out/umi-defconfig-resolver.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }

say "== 1. umi_defconfig / board.toml 全盘位置（/home/unixnu/code）=="
find /home/unixnu/code -maxdepth 8 -name 'umi_defconfig' -printf '%p\n' 2>/dev/null | head -20 >> "$OUT"
find /home/unixnu/code -maxdepth 8 -name 'board.toml' -printf '%p\n' 2>/dev/null | head -20 >> "$OUT"
say "-- umi 设备仓 git 目录 --"
find /home/unixnu/code -maxdepth 6 -type d -name '.git' -printf '%p\n' 2>/dev/null | head -20 >> "$OUT"

say
say "== 2. 谁把 CONFIG_XNU_* 变成 XNU_* 环境变量 =="
grep -rn 'CONFIG_XNU_\|_defconfig' "$T/scripts" 2>/dev/null | grep -v Binary | head -40 >> "$OUT"
say "-- unixnu CLI 本体 --"
ls -1 /home/unixnu/code/umi-work-pin 2>/dev/null | head -20 >> "$OUT"
find /home/unixnu/code -maxdepth 5 -name 'unixnu' -printf '%p -> %l\n' 2>/dev/null | head -10 >> "$OUT"
command -v unixnu >> "$OUT" 2>&1

say
say "== 3. mockfs 前置件 =="
say "-- vfs_conf.o.json 编译记录 --"
ls -l "$T/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/bsd/DEVELOPMENT/vfs_conf.o.json" >> "$OUT" 2>&1
say "-- mockfs 源在位 --"
ls -1 "$T/.cache/xnu-work/bsd/miscfs/mockfs" >> "$OUT" 2>&1
say "-- scripts/linux shim --"
ls -1 "$T/scripts/linux" >> "$OUT" 2>&1
say "-- xcrun / ar 可用性 --"
echo "PATH=$PATH" >> "$OUT"
command -v xcrun >> "$OUT" 2>&1
command -v ar >> "$OUT" 2>&1
command -v clang >> "$OUT" 2>&1
say "-- 上次内核构建是怎么起来的（找 wrapper/日志）--"
ls -1t /home/unixnu/code/umi-work-pin/out/umi-xnu 2>/dev/null | head -15 >> "$OUT"
ls -1t /mnt/e/Code/HackIos/tools-wsl/*.sh 2>/dev/null | head -8 >> "$OUT"

say
say "== 4. 当前 vfs_conf.o.json 内容前 1200 字符 =="
head -c 1200 "$T/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/bsd/DEVELOPMENT/vfs_conf.o.json" >> "$OUT" 2>&1
say
say done
