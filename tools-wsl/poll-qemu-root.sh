#!/bin/bash
# 轮询 run-06-root：产物、uart 尾部、是否还在跑
D=/home/unixnu/code/umi-work-pin/out/umi-qemu/run-06-root
{
  echo "== $(date +%H:%M:%S)"
  ls -l "$D" 2>&1 | head -12
  echo "== uart 行数=$(wc -l < "$D/gdb-uart.log" 2>/dev/null || echo 0)"
  awk 'length($0)<300' "$D/gdb-uart.log" 2>/dev/null | tail -20
  echo "== 观察器日志尾部"
  tail -8 /home/unixnu/code/UniXNU-main/out/unixnu-logs/qemu-run-06-root.log 2>/dev/null
  echo "== 在跑?"; pgrep -af "run_umi_qemu|gdb-stop-root" | head -3
  echo "== 停点"; [ -f "$D/gdb-stop.json" ] && head -c 900 "$D/gdb-stop.json"
} > /mnt/e/Code/HackIos/out/probes/qemu-root-poll.txt 2>&1
echo OK
