#!/bin/bash
OUT=/home/unixnu/code/umi-work-pin/out/umi-qemu/run-08-rev3
L=/home/unixnu/code/UniXNU-main/out/unixnu-logs/qemu-run-08-rev3.launch.log
echo "=== 驱动还在跑吗 ==="
pgrep -fa "run_umi_qemu.py|qemu-system-aarch64" | head -3
echo "=== launch 日志 ==="
tail -12 "$L" 2>/dev/null
echo "=== 产物 ==="
ls -la "$OUT" 2>/dev/null
echo "=== uart 尾部 40 行 ==="
tail -40 "$OUT/gdb-uart.log" 2>/dev/null
echo "=== stop 判据 ==="
for f in gdb-stop.json gdb-failure.json; do
  [ -f "$OUT/$f" ] && { echo "-- $f"; head -c 1200 "$OUT/$f"; echo; }
done
