#!/bin/bash
# 随手看一眼 25z 构建到哪了（只读，不动进程）。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/n2-build-tail.txt
: > "$OUT"
exec >>"$OUT" 2>&1
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
L=$(cat "$LOGD/kernel-walk-latest.txt" 2>/dev/null)
P=$(cat "$LOGD/kernel-walk.pid" 2>/dev/null)
echo "LOG=$L"
echo "PID=$P"
if [ -n "$P" ] && kill -0 "$P" 2>/dev/null; then echo "STATE=RUNNING"; else echo "STATE=DONE-OR-GONE"; fi
echo
echo "== 日志尾 40 行（去色）=="
sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' "$L" 2>/dev/null | tail -40
echo
echo "== 有没有 error / 补丁重放记录 =="
sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' "$L" 2>/dev/null | grep -in 'error\|fork-probe\|patch' | tail -20
echo "== done $(date -u +%FT%TZ)"
