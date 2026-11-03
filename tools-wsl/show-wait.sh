#!/bin/bash
set -u
L=$(cat /home/unixnu/code/UniXNU-main/out/unixnu-logs/unittest-latest.txt)
echo "=== umi-wait 相关上下文 ==="
grep -n "umi-wait" "$L" | head -4
awk '/umi-wait/{found=1} found{print; c++} c>25{exit}' "$L" | head -30
