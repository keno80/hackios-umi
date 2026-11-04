#!/bin/bash
# run-23-fork 为什么 15s 就退出：把 runner/stderr/launch/gdb-stop 全倒出来。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/n10-why-exited.txt
: > "$OUT"
exec >>"$OUT" 2>&1
RUN=/home/unixnu/code/umi-work-pin/out/umi-qemu/run-23-fork
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs

echo "== 1. launch log 全文 =="
cat "$LOGD/qemu-run-23-fork.launch.log" 2>/dev/null | sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g'

echo
echo "== 2. runner.log =="
cat "$RUN/runner.log" 2>/dev/null

echo
echo "== 3. gdb-stderr.log =="
cat "$RUN/gdb-stderr.log" 2>/dev/null

echo
echo "== 4. gdb-stop.json 全文 =="
cat "$RUN/gdb-stop.json" 2>/dev/null

echo
echo "== 5. 对照：run-22-walk2 的 runner.log 尾 =="
tail -20 /home/unixnu/code/umi-work-pin/out/umi-qemu/run-22-walk2/runner.log 2>/dev/null
echo "== done $(date -u +%FT%TZ)"
