#!/bin/bash
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/screenhost.txt
: > "$OUT"
bash /mnt/e/Code/HackIos/tools-wsl/fix-vc-tail.sh >> "$OUT" 2>&1
bash /mnt/e/Code/HackIos/tools-wsl/umi-screen-test/build-test.sh >> "$OUT" 2>&1
bash /mnt/e/Code/HackIos/tools-wsl/umi-screen-test/to-png.sh >> "$OUT" 2>&1
grep -n 'umi_scr_bg = 0xFF' /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work/osfmk/console/video_console.c >> "$OUT" 2>&1
