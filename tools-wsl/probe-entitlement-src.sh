#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/entitlement-src.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho

say "== 1. IOKitBSDInit.cpp 1580-1665 =="
sed -n '1580,1665p' "$X/iokit/bsddev/IOKitBSDInit.cpp" >> "$OUT" 2>&1

say
say "== 2. 反汇编 0xfffffff00798e700 - 0xfffffff00798e7a0 =="
llvm-objdump -d --macho --start-address=0xfffffff00798e700 --stop-address=0xfffffff00798e7a0 "$K" 2>&1 | head -40 >> "$OUT"
say done
