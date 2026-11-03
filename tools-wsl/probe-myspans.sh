#!/bin/bash
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/myspans.txt
: > "$OUT"
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
for f in osfmk/console/video_console.c osfmk/arm/arm_init.c osfmk/kern/startup.c osfmk/kern/debug.c; do
  echo "===== $f =====" >> "$OUT"
  grep -n 'umi_screen\|umi_scr\|UMI_SCR\|umi_panic' "$W/$f" >> "$OUT" 2>&1
  echo "----- total lines: $(wc -l < "$W/$f")" >> "$OUT"
done
echo "===== how prepare applies patches =====" >> "$OUT"
grep -n 'patch\|apply\|sort' /home/unixnu/code/umi-work-pin/devices/umi/scripts/prepare-xnu-source.py | head -40 >> "$OUT" 2>&1
