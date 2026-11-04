#!/bin/bash
# J6：等 run-19 的 screen.png 落地，把挂根判据与截屏一起取回 Windows 侧
set -u
LOG=/mnt/e/Code/HackIos/out/probes/j6-qemu-screen.txt
: > "$LOG"
exec >>"$LOG" 2>&1

WS=/home/unixnu/code/umi-work-pin
OUT=$WS/out/umi-qemu/run-19-probe-mockfs
SHOTS=/mnt/e/Code/HackIos/out/screens
mkdir -p "$SHOTS"

echo "== 0. 等 screen.png（最多 480 s）=="
start=$(date +%s)
while [ $(( $(date +%s) - start )) -lt 480 ]; do
  if [ -f "$OUT/screen.png" ]; then echo "screen.png 出现，用时 $(( $(date +%s) - start )) s"; break; fi
  sleep 15
  echo "[$(( $(date +%s) - start )) s] $(ls "$OUT" 2>/dev/null | tr '\n' ' ')"
done
echo
echo "== 1. 目录 =="
ls -la "$OUT" 2>/dev/null
echo
echo "== 2. uart 全文 =="
cat "$OUT/gdb-uart.log" 2>/dev/null
echo
echo "== 3. 判据计数 =="
for s in MOUNTFAIL 'MR exhausted' 'MR mockfs' 'MR bdevvp' 'vfs_mountroot enter' 'SETCONF' 'root authentication' load_init_program 'SystemOS mount' 'Data mount' PANIC 'panic_trap' 'launchd' '_main_thread' 'umountall'; do
  printf '  %-22s %s\n' "$s" "$(grep -c "$s" "$OUT/gdb-uart.log" 2>/dev/null)"
done
echo
echo "== 4. stop 证据 =="
for f in gdb-stop.json gdb-failure.json provenance.json; do
  [ -f "$OUT/$f" ] && { echo "-- $f --"; head -50 "$OUT/$f"; }
done
echo
echo "== 5. 取回截屏 =="
if [ -f "$OUT/screen.png" ]; then
  cp -f "$OUT/screen.png" "$SHOTS/run-19-probe-mockfs.png"
  ls -l "$SHOTS/run-19-probe-mockfs.png" | sed 's#^# #'
  sha256sum "$SHOTS/run-19-probe-mockfs.png" | sed 's#^# #'
else
  echo "screen.png 仍缺失"
fi
echo "DONE"
