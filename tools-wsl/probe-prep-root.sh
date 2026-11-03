#!/bin/bash
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/prep-root.txt
R=/home/unixnu/code/umi-work-pin
: > "$OUT"
echo "== head of devices/umi/scripts/prepare-xnu-source.py ==" >> "$OUT"
sed -n '1,40p' "$R/devices/umi/scripts/prepare-xnu-source.py" >> "$OUT" 2>&1
echo "== tree patches dirs ==" >> "$OUT"
ls -d "$R/out/umi-xnu/umi/tree/patches/"* 2>&1 >> "$OUT"
echo "== is tree/patches/umi-xnu a symlink? ==" >> "$OUT"
ls -l "$R/out/umi-xnu/umi/tree/patches/" 2>&1 | head -20 >> "$OUT"
echo "== devices/umi/patches listing ==" >> "$OUT"
ls -l "$R/devices/umi/patches/" 2>&1 | head -20 >> "$OUT"
echo "== last build logdir + status ==" >> "$OUT"
ls -dt "$R"/out/umi-xnu/logs/* 2>/dev/null | head -5 >> "$OUT"
find "$R/out" -maxdepth 4 -name 'source-build-status.json' 2>/dev/null >> "$OUT"
echo "== how the last kernel build was launched ==" >> "$OUT"
cat /mnt/e/Code/HackIos/tools-wsl/run-xnu-prepare.sh >> "$OUT" 2>&1
