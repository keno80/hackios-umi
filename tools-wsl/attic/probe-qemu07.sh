#!/bin/bash
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/qemu07.txt
L=/home/unixnu/code/UniXNU-main/out/unixnu-logs
D=/home/unixnu/code/umi-work-pin/out/umi-qemu/run-07-screen
: > "$OUT"
echo "== launch log ==" >> "$OUT"
tail -20 "$L/qemu-run-07-screen.launch.log" >> "$OUT" 2>&1
echo "== qemu main log ==" >> "$OUT"
tail -30 "$L/qemu-run-07-screen.log" >> "$OUT" 2>&1
echo "== out dir ==" >> "$OUT"
ls -l "$D" >> "$OUT" 2>&1
echo "== uart tail ==" >> "$OUT"
tail -30 "$D/gdb-uart.log" >> "$OUT" 2>&1
echo "== procs ==" >> "$OUT"
pgrep -af 'run_umi_qemu|qemu-system' >> "$OUT" 2>&1 | head -5
