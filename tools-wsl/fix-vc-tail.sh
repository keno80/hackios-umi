#!/bin/bash
set -euo pipefail
VC=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work/osfmk/console/video_console.c
TAIL=/mnt/e/Code/HackIos/tools-wsl/umi_screen_tail.c
cp "$VC" "$VC.bak-before-tail-fix"
head -n 3312 "$VC" > /tmp/vc-head.c
cat /tmp/vc-head.c "$TAIL" > /tmp/vc-new.c
cp /tmp/vc-new.c "$VC"
echo "lines now: $(wc -l < "$VC")"
sed -n '3310,3320p' "$VC"
