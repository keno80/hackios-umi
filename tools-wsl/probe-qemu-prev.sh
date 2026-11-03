#!/bin/bash
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/qemu-prev.txt
Q=/home/unixnu/code/umi-work-pin/out/umi-qemu
L=/home/unixnu/code/UniXNU-main/out/unixnu-logs
: > "$OUT"
for d in run-05-root run-06-root; do
  echo "===== $Q/$d =====" >> "$OUT"
  ls -l "$Q/$d" >> "$OUT" 2>&1
  echo "----- stop json -----" >> "$OUT"
  for f in gdb-stop.json gdb-failure.json; do
    [ -f "$Q/$d/$f" ] && head -c 1200 "$Q/$d/$f" >> "$OUT" && echo >> "$OUT"
  done
done
echo "===== run-06 launch log head =====" >> "$OUT"
head -20 "$L/qemu-run-06-root.log" >> "$OUT" 2>&1
echo "===== run-06 uart tail =====" >> "$OUT"
tail -25 "$Q/run-06-root/gdb-uart.log" >> "$OUT" 2>&1
