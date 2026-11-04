set -u
OUT=/mnt/e/Code/HackIos/out/probes/m11-walk-result.txt
: > "$OUT"
exec >>"$OUT" 2>&1
WS=/home/unixnu/code/umi-work-pin
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
NAME=run-21-walk
RUN=$WS/out/umi-qemu/$NAME
L=$LOGD/qemu-$NAME.launch.log
echo "== 1. 等完成标记（run_umi_qemu exit=），最多 1500s =="
for i in $(seq 1 300); do
  if grep -q "run_umi_qemu exit=" "$L" 2>/dev/null; then
    echo "DONE after $((i*5))s"; break
  fi
  sleep 5
done
grep -n "run_umi_qemu exit=" "$L" 2>/dev/null || echo "NO-COMPLETE-MARKER"
echo
echo "== 2. run 目录全列 =="
ls -la "$RUN" 2>/dev/null
echo
echo "== 3. launch 日志全文 =="
cat "$L"
echo
echo "== 4. 所有 json 全文 =="
for f in "$RUN"/*.json; do
  [ -f "$f" ] || continue
  echo "---- $(basename "$f") ($(stat -c%s "$f") B)"
  cat "$f"
  echo
done
echo
echo "== 5. uart =="
cat "$RUN/gdb-uart.log" 2>/dev/null
echo "== done $(date -u +%FT%TZ)"
