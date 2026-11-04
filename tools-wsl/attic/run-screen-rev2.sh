#!/bin/bash
set -uo pipefail
TW=/mnt/e/Code/HackIos/tools-wsl
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
LOG=/mnt/e/Code/HackIos/out/probes/screen-rev2.txt
: > "$LOG"

echo "== 1. install painter tail ==" >> "$LOG"
bash "$TW/fix-vc-tail.sh" >> "$LOG" 2>&1

echo "== 2. debug.c panic buffer ==" >> "$LOG"
grep -n "umi_panic_line\[" "$X/osfmk/kern/debug.c" >> "$LOG" 2>&1
sed -i 's/char umi_panic_line\[160\];/static char umi_panic_line[1200];/' "$X/osfmk/kern/debug.c"
grep -n "umi_panic_line\[" "$X/osfmk/kern/debug.c" >> "$LOG" 2>&1

echo "== 3. host compile + render ==" >> "$LOG"
bash "$TW/umi-screen-test/build-test.sh" >> "$LOG" 2>&1
bash "$TW/umi-screen-test/to-png.sh" >> "$LOG" 2>&1
echo "== done ==" >> "$LOG"
cp "$LOG" /tmp/screen-rev2-copy.txt 2>/dev/null || true
