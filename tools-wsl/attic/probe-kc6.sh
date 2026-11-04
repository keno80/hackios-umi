#!/bin/bash
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/kernel-check6.txt
VO=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/osfmk/DEVELOPMENT/video_console.o
: > "$OUT"
echo "== all strings in video_console.o (non-path) ==" >> "$OUT"
strings -a -n 3 "$VO" | grep -v '^/' | head -60 >> "$OUT" 2>&1
echo "== disasm umi_screen_mark ==" >> "$OUT"
llvm-objdump -d --start-address=0x4e04 --stop-address=0x4ecc "$VO" >> "$OUT" 2>&1
echo "== sections with content sizes ==" >> "$OUT"
llvm-objdump -h "$VO" | head -40 >> "$OUT" 2>&1
