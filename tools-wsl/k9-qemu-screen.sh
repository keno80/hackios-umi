#!/bin/bash
# K 步：等 run-20-el0 的 screen.png 落地，把 EL0 判据与截屏一起取回 Windows 侧。
# QEMU 侧 uart 能看到 printf，但真机判据只认屏；这一步是「探针本身有效」的对照。
set -u
LOG=/mnt/e/Code/HackIos/out/probes/k9-qemu-screen.txt
: > "$LOG"
exec >>"$LOG" 2>&1

WS=/home/unixnu/code/umi-work-pin
OUT=$WS/out/umi-qemu/run-20-el0
SHOTS=/mnt/e/Code/HackIos/out/screens
mkdir -p "$SHOTS"

echo "== 0. 等 screen.png（最多 600 s）=="
start=$(date +%s)
while [ $(( $(date +%s) - start )) -lt 600 ]; do
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
for s in 'MR mockfs' 'MR exhausted' 'vfs_mountroot mounted' load_init_program 'INIT try' 'INIT exec' 'INIT err' 'EL0 MACH' 'EL0 UNIX' 'launchd' PANIC 'panic_trap'; do
  printf '  %-24s %s\n' "$s" "$(grep -c "$s" "$OUT/gdb-uart.log" 2>/dev/null)"
done
echo
echo "== 4. stop 证据 =="
for f in gdb-stop.json gdb-failure.json provenance.json; do
  [ -f "$OUT/$f" ] && { echo "-- $f --"; head -50 "$OUT/$f"; }
done
echo
echo "== 5. 取回截屏 =="
if [ -f "$OUT/screen.png" ]; then
  cp -f "$OUT/screen.png" "$SHOTS/run-20-el0.png"
  ls -l "$SHOTS/run-20-el0.png" | sed 's#^# #'
  sha256sum "$SHOTS/run-20-el0.png" | sed 's#^# #'
else
  echo "screen.png 仍缺失"
fi
echo "DONE"
