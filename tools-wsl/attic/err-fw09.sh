#!/bin/bash
LOG=/home/unixnu/code/umi-work-pin/out/umi-fw/run-09/firmware.log
grep -n "error:" "$LOG" | head -12
echo "=== 上下文 ==="
awk '/UmiBootLog.c:/,/4 errors generated/' "$LOG" | head -60
