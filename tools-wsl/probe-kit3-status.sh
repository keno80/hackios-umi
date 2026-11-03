#!/bin/bash
set -u
R=/home/unixnu/code/umi-work-pin/out/umi-qemu/run-12-kit3
O=/mnt/e/Code/HackIos/out/qemu12-status.txt
{
  echo "== 进程（qemu / runner）"
  pgrep -af 'qemu-system-aarch64|run_umi_qemu' | head -4
  echo "== run 目录"
  ls -l --time-style=+%H:%M:%S "$R" 2>&1
  echo "== uart 尾部"
  tail -c 900 "$R/gdb-uart.log" 2>&1
  echo "== stop / failure json"
  for f in gdb-stop.json failure.json; do
    [ -f "$R/$f" ] && { echo "-- $f"; head -c 400 "$R/$f"; echo; }
  done
  echo "== runner.log"
  tail -8 "$R/runner.log" 2>&1
} > "$O" 2>&1
echo ok
