#!/bin/bash
# 取证：读 run-10-kit 的 QEMU 自测结果（uart / stop / failure / 截屏）
O=/home/unixnu/code/umi-work-pin/out/umi-qemu/run-10-kit
L=/home/unixnu/code/UniXNU-main/out/unixnu-logs
OUT=/mnt/e/Code/HackIos/out
clean() { tr -cd '\11\12\40-\176'; }
{
  echo "== launch log"
  tail -c 800 "$L/qemu-run-10-kit.launch.log" 2>&1 | clean
  echo "== run dir"
  ls -l "$O" 2>&1
  echo "== uart tail"
  [ -f "$O/gdb-uart.log" ] && { wc -c < "$O/gdb-uart.log"; tail -c 3000 "$O/gdb-uart.log" | clean; }
  echo "== stop/failure json"
  for f in gdb-stop.json gdb-failure.json; do
    [ -f "$O/$f" ] && { echo "-- $f"; head -c 3000 "$O/$f"; echo; }
  done
  echo "== running?"
  pgrep -af 'qemu-system-aarch64' | head -2
} > "$OUT/qemu-run10.txt" 2>&1
