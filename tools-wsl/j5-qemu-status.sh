#!/bin/bash
# J5：看 QEMU run-19 跑到哪了（证据文件驱动，不用 pgrep）
set -u
LOG=/mnt/e/Code/HackIos/out/probes/j5-qemu-status.txt
: > "$LOG"
exec >>"$LOG" 2>&1

WS=/home/unixnu/code/umi-work-pin
OUT=$WS/out/umi-qemu/run-19-probe-mockfs
LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs

echo "== 1. 目录内容 =="
ls -la "$OUT" 2>/dev/null
echo
echo "== 2. launcher 日志尾 =="
tail -15 "$LOGD/qemu-run-19-probe-mockfs.launch.log" 2>/dev/null
echo
echo "== 3. qemu 主日志尾 =="
tail -25 "$LOGD/qemu-run-19-probe-mockfs.log" 2>/dev/null
echo
echo "== 4. uart 尾部（有没有挂根后的阶段文本）=="
if [ -f "$OUT/gdb-uart.log" ]; then
  wc -l < "$OUT/gdb-uart.log" | sed 's#^#uart lines=#'
  tail -30 "$OUT/gdb-uart.log"
  echo "-- 关键判据 --"
  for s in MOUNTFAIL 'MR exhausted' 'MR mockfs' 'mockfs_mountroot' 'root authentication' load_init_program 'SystemOS mount' 'Data mount' panic PANIC; do
    printf '  %-22s %s\n' "$s" "$(grep -c "$s" "$OUT/gdb-uart.log" 2>/dev/null)"
  done
else
  echo "无 gdb-uart.log"
fi
echo
echo "== 5. screen.png 在不在 =="
ls -la "$OUT/screen.png" 2>/dev/null || echo "screen.png 还没生成"
echo
echo "== 6. stop/failure 证据 =="
for f in gdb-stop.json gdb-failure.json; do
  [ -f "$OUT/$f" ] && { echo "-- $f --"; head -40 "$OUT/$f"; }
done
echo "DONE"
