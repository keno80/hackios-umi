#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/amfi-global.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
export PATH="/opt/unixnu-linux/CommandLineTools/usr/bin:/opt/unixnu-linux/bin:$PATH"

say "== 1. 内核里的 AMFI 相关符号 =="
xcrun nm "$K" 2>/dev/null | grep -iE 'amfi' | head -12 >> "$OUT"

say
say "== 2. amfi.h 里 amfi 的声明 =="
find "$X" -name 'amfi.h' -path '*libkern*' 2>/dev/null | head -3 >> "$OUT"
H=$(find "$X" -name 'amfi.h' -path '*libkern*' 2>/dev/null | head -1)
grep -n 'amfi\b\|extern\|define amfi\|struct amfi' "$H" 2>/dev/null | head -25 >> "$OUT"

say
say "== 3. 谁给 amfi 赋值（注册点）=="
grep -rn 'amfi = \|amfi= \|_amfi_init\|AMFIInit\|osfmk_amfi' "$X/libkern/" "$X/bsd/" 2>/dev/null | head -12 >> "$OUT"

say
say "== 4. OSEntitlements 在结构里的偏移线索 =="
grep -n -B6 -A10 'OSEntitlements' "$H" 2>/dev/null | head -40 >> "$OUT"
say done
