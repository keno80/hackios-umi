#!/bin/bash
# 确认上游 boot-progress 的「实现件」到底有没有，以及我们树里的 gate。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/f-kit-absent.txt
: > "$OUT"
exec >>"$OUT" 2>&1
echo "== 全盘找 kits 目录 =="
find /home/unixnu/code -maxdepth 4 -type d -name kits 2>/dev/null | head -20
echo
echo "== 全盘找 BootProgress.c / BootFaultProbe.c / BootWatchdogPolicy.c =="
find /home/unixnu/code -name 'BootProgress.c' -o -name 'BootFaultProbe.c' \
  -o -name 'BootWatchdogPolicy.c' 2>/dev/null | head -20
echo
echo "== 全盘找 libBootProgress.a =="
find /home/unixnu/code -name 'libBootProgress.a' 2>/dev/null | head -10
echo
echo "== zzz-boot-progress.patch 里新增了哪些文件（+++ 行）=="
grep -n '^+++ ' /home/unixnu/code/UniXNU-main/patches/xnu/zzz-boot-progress.patch 2>/dev/null
echo
echo "== 该 patch 里 boot_progress_stage 的实现体是否出现（看有没有函数体）=="
grep -n 'boot_progress_stage' /home/unixnu/code/UniXNU-main/patches/xnu/zzz-boot-progress.patch 2>/dev/null | head -20
echo
echo "== 我们的 umi 构建是怎么调 kernel.py 的（XNU_BOOT_PROGRESS 有没有被覆盖）=="
grep -rn "XNU_BOOT_PROGRESS\|BOOT_PROGRESS" /mnt/e/Code/HackIos/tools-wsl/*.sh 2>/dev/null | head -20
echo
echo "== kernel.py:190..210 上下文 =="
sed -n '190,210p' /home/unixnu/code/UniXNU-main/scripts/unixnu/kernel.py 2>/dev/null
