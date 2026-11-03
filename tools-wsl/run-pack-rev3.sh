#!/bin/bash
set -uo pipefail
LOG=/mnt/e/Code/HackIos/out/pack-rev3.txt
: > "$LOG"
WS=/home/unixnu/code/umi-work-pin

echo "== 1. payload volume ==" >> "$LOG"
python3 /mnt/e/Code/HackIos/tools-wsl/build-xnu-payload.py >> "$LOG" 2>&1
echo "rc=$?" >> "$LOG"

echo "== 2. bootimg ==" >> "$LOG"
bash /mnt/e/Code/HackIos/tools-wsl/pack-menu-xnu.sh >> "$LOG" 2>&1
echo "pack rc=$?" >> "$LOG"

echo "== 3. verify ==" >> "$LOG"
python3 /mnt/e/Code/HackIos/tools-wsl/verify-menu-xnu.py >> "$LOG" 2>&1
echo "verify rc=$?" >> "$LOG"
echo "== done ==" >> "$LOG"
