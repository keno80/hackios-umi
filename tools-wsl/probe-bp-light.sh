#!/bin/bash
# boot-progress 能否在 umi 构建里点亮：实现件、构建脚本、绑屏入口、gate 开关。
set -u
OUT=/mnt/e/Code/HackIos/out/f-bp-light.txt
: > "$OUT"
exec >>"$OUT" 2>&1
U=/home/unixnu/code/UniXNU-umi
W=/home/unixnu/code/umi-work-pin
M=/home/unixnu/code/UniXNU-main

echo "== devices/umi/package/boot-progress 清单 =="
ls -la $U/package/boot-progress/
echo
echo "== BootProgress.c 全文 =="
cat $U/package/boot-progress/BootProgress.c
echo
echo "== build-boot-progress.py（设备仓）全文 =="
cat $U/scripts/build-boot-progress.py 2>&1 | head -80
echo
echo "== 设备仓 build-xnu-4k-baseline.sh 里 BOOT_PROGRESS 相关 =="
grep -n "BOOT_PROGRESS\|boot-progress\|boot_progress" $U/scripts/build-xnu-4k-baseline.sh 2>&1 | head -40
echo
echo "== zzz-boot-progress.patch 是否在设备仓补丁里 =="
ls $U/patches/umi-xnu/ 2>/dev/null | head -40
echo "--- main 树 patches/xnu 里的 ---"
ls $M/patches/xnu/ 2>/dev/null | head -40
echo
echo "== patch 的 video_console.c hunk =="
sed -n '58,124p' $M/patches/xnu/zzz-boot-progress.patch
echo
echo "== patch 的 boot_progress.h + Makefile hunk =="
sed -n '273,330p' $M/patches/xnu/zzz-boot-progress.patch
