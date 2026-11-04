#!/bin/bash
# K 步收尾之一：取回 pack 自检 8 项明细 + 确认交付卷里的菜单标题真是 K-EL0。
# pack-menu-xnu.sh 把 stdout 重定向进 ext4 里的日志，直接 wsl cat 会撞 UTF-16 二进制输出，所以落脚本文件。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/k10-pack-check.txt
: > "$OUT"
exec >>"$OUT" 2>&1

LOG=/home/unixnu/code/umi-work-pin/out/umi-fw/pack-xnu.log
STAGE=/home/unixnu/code/umi-work-pin/out/umi/xnu/umi-stage

echo "== 1. pack 自检日志尾 =="
ls -la "$LOG"
tail -40 "$LOG"

echo
echo "== 2. 判定行 =="
grep -n 'RESULT' "$LOG" || echo "NO-RESULT-LINE"

echo
echo "== 3. 卷内菜单标题 =="
for d in "$STAGE" /home/unixnu/code/umi-work-pin/out/umi/xnu; do
  f="$d/EFI/UniXNU/unixnu.toml"
  [ -f "$f" ] && { echo "-- $f"; grep -n 'title\|args\|initrd' "$f"; }
done

echo
echo "== 4. 交付镜像指纹 =="
IMG=/mnt/e/Code/HackIos/out/images/umi-uefi-menu-el0.img
ls -l "$IMG" | sed 's#^# #'
sha256sum "$IMG" | sed 's#^# #'
echo "-- 上一档是否还在（避免两份同名混淆）--"
ls -l /mnt/e/Code/HackIos/out/images/*.img 2>/dev/null | sed 's#^# #'
echo done
