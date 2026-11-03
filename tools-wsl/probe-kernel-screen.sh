#!/bin/bash
# Poll the running on-screen-marker kernel build: state, elapsed, last lines, error count.
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
LOG=$(ls -t "$LOGD"/kernel-screen-*.log | head -1)
PID=$(cat "$LOGD/kernel-screen.pid")
echo "LOG=$LOG"
if kill -0 "$PID" 2>/dev/null; then
  echo "STATE=RUNNING pid=$PID"
else
  echo "STATE=EXITED pid=$PID"
fi
echo "SIZE=$(stat -c %s "$LOG") bytes  LINES=$(wc -l < "$LOG")"
echo "AGE=$(ps -o etimes= -p "$PID" 2>/dev/null | tr -d ' ')s"
echo "--- last 20 ---"
tail -20 "$LOG"
echo "--- error/fatal hits ---"
grep -ciE "error:|fatal error|Traceback" "$LOG"
grep -inE "error:|fatal error|Traceback" "$LOG" | tail -5
