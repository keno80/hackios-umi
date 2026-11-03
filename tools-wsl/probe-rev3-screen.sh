#!/bin/bash
OUT=/home/unixnu/code/umi-work-pin/out/umi-qemu/run-08-rev3
echo "=== 进程 ==="
pgrep -fa "run_umi_qemu.py|qemu-system-aarch64" | head -2
echo "=== 产物 ==="
ls -la "$OUT" | tail -12
echo "=== stop json 头部 ==="
head -c 700 "$OUT/gdb-stop.json" 2>/dev/null
echo
echo "=== uart 尾部 25 行 ==="
tail -25 "$OUT/gdb-uart.log" 2>/dev/null | cat -v | cut -c1-160
echo "=== 取屏 ==="
[ -f "$OUT/screen.png" ] && cp "$OUT/screen.png" /mnt/e/Code/HackIos/out/rev3-qemu-screen.png && echo "copied screen.png"
echo "=== runner.log ==="
tail -8 "$OUT/runner.log" 2>/dev/null
