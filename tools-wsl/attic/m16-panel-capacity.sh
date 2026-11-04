#!/bin/bash
# 面板容量：boot_progress_stage 画到第几行会停/滚？走查新增 20+ 行会不会挤掉关键证据行。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/m16-panel-capacity.txt
: > "$OUT"
exec >>"$OUT" 2>&1
DEV=/home/unixnu/code/UniXNU-umi
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== 1. boot_progress 实现在哪 =="
grep -rln 'boot_progress_stage' $X --include='*.c' --include='*.h' 2>/dev/null | head -20

echo
echo "== 2. 定义体（找 boot_progress_stage 的实现文件）=="
for f in $(grep -rl 'void boot_progress_stage\|boot_progress_stage(const' $X --include='*.c' 2>/dev/null | head -4); do
  echo "---- $f"
  awk '/boot_progress_stage/{p=1} p{print NR": "$0} p&&/^}/{c++; if(c>0&&/^}/){exit}}' "$f" | head -60
done

echo
echo "== 3. 行数/滚动常量 =="
grep -rn 'UMI_STAGE\|stage_count\|MAX_STAGE\|rows\|ROW\|scroll\|wrap' \
  $(grep -rl 'boot_progress_stage' $X --include='*.c' --include='*.h' 2>/dev/null | head -6) 2>/dev/null | head -40

echo
echo "== 4. 相关补丁原文（17 screen / 20 boot-stage）=="
ls $DEV/patches/umi-xnu/ | grep '^z' | sort | sed -n '17p;20p'
for p in $(ls $DEV/patches/umi-xnu/ | grep '^z' | sort | sed -n '17p;20p'); do
  echo "======== $p"
  head -80 "$DEV/patches/umi-xnu/$p"
done

echo
echo "== 5. 当前屏上已用行数（run-21 面板实测：从 screen.png 数）=="
echo "（见 run-21 屏：约 24 行可见）"
echo "== done $(date -u +%FT%TZ)"
