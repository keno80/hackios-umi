#!/bin/bash
set -u
LOG=$(cat /home/unixnu/code/UniXNU-main/out/unixnu-logs/kernel-screen-latest.txt)
KL=$(grep -o '/[^ ]*kernel\.log' "$LOG" | tail -1)
O=/mnt/e/Code/HackIos/out/build-err.txt
{
  echo "kernel step log = $KL"
  echo "== driver log =="
  cat "$LOG"
  echo "== ld/undefined/Error 1 hits in kernel.log =="
  grep -nE "ld:|undefined|Error 1|error:|fatal" "$KL" 2>/dev/null | tail -30
  echo "== kernel.log last 30 =="
  tail -30 "$KL" 2>/dev/null
} > "$O" 2>&1
