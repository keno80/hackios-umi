#!/bin/bash
# 找出构建实际消费的 early-entry-trace.patch 是哪一份
set -u
OUT=/mnt/e/Code/HackIos/out/probes/h-patch-source.txt
exec >"$OUT" 2>&1

echo "== 全盘找同名补丁，看谁带 UMI_BAND =="
find /home/unixnu/code /mnt/e/Code/HackIos -name "early-entry-trace.patch" 2>/dev/null | while read -r f; do
  printf "band=%s size=%s mtime=%s\n  %s\n" "$(grep -c UMI_BAND "$f")" "$(stat -c %s "$f")" "$(stat -c %y "$f" | cut -c1-19)" "$f"
done

echo
echo "== 找同名 inc =="
find /home/unixnu/code /mnt/e/Code/HackIos -name "umi-early-trace.inc" 2>/dev/null | while read -r f; do
  printf "band=%s mtime=%s\n  %s\n" "$(grep -c 'macro UMI_BAND' "$f")" "$(stat -c %y "$f" | cut -c1-19)" "$f"
done

echo
echo "== prepare-xnu-source.py 从哪里取补丁/inc =="
grep -n "patches\|\.inc\|ROOT\s*=" /home/unixnu/code/UniXNU-umi/scripts/prepare-xnu-source.py 2>/dev/null | head -20

echo
echo "== devices/umi 绑定状态 =="
ls -ld /home/unixnu/code/umi-work-pin/devices/umi /home/unixnu/code/UniXNU-umi 2>&1
mount | grep -i "umi" | head -5
