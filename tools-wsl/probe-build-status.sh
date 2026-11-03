#!/bin/bash
set -u
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
O=/mnt/e/Code/HackIos/out/build-status.txt
LOG=$(cat "$LOGD/kernel-screen-latest.txt")
PID=$(cat "$LOGD/kernel-screen.pid")
{
  echo "LOG=$LOG"
  if kill -0 "$PID" 2>/dev/null; then echo "STATE=RUNNING pid=$PID etime=$(ps -o etimes= -p "$PID" | tr -d ' ')s"; else echo "STATE=EXITED pid=$PID"; fi
  echo "SIZE=$(stat -c %s "$LOG") LINES=$(wc -l < "$LOG")"
  echo "--- last 12 ---"
  tail -12 "$LOG"
  echo "--- register_crypto / crypto hits ---"
  grep -n "register_crypto\|umi_crypto\|crypto_kit" "$LOG" | tail -8
  echo "--- error hits ---"
  grep -ciE "error:|fatal error|Traceback" "$LOG"
  grep -inE "error:|fatal error|Traceback" "$LOG" | tail -6
} > "$O" 2>&1
