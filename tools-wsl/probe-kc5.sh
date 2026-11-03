#!/bin/bash
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/kernel-check5.txt
VO=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/osfmk/DEVELOPMENT/video_console.o
KER=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
: > "$OUT"
echo "== llvm-nm video_console.o umi ==" >> "$OUT"
llvm-nm "$VO" | grep -i umi >> "$OUT" 2>&1
echo "== strings video_console.o ==" >> "$OUT"
strings -a "$VO" | grep -i -E 'umi |screen|panic|fb=|row=|geom|UMI' | head -40 >> "$OUT" 2>&1
echo "== disasm umi_scr_setup ==" >> "$OUT"
llvm-objdump -d "$VO" | awk '/_umi_scr_setup:/{f=1} f{print} f&&/^$/{exit}' | head -80 >> "$OUT" 2>&1
echo "== macho symbols umi ==" >> "$OUT"
llvm-nm "$KER" 2>&1 | grep -i -E 'umi_screen|umi_scr' | head -30 >> "$OUT"
echo "== macho strings UMI ==" >> "$OUT"
strings -a "$KER" | grep -E 'UMI' | head -20 >> "$OUT" 2>&1
