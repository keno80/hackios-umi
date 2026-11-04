#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/amfi-deref-scope.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

say "== 1. amfi-> 解引用总数与按文件分布 =="
grep -rn 'amfi->' "$X" --include='*.c' --include='*.cpp' --include='*.h' 2>/dev/null | wc -l >> "$OUT"
grep -rl 'amfi->' "$X" --include='*.c' --include='*.cpp' 2>/dev/null | head -20 >> "$OUT"

say
say "== 2. IOKitBSDInit.cpp 里 amfi-> 的全部出现 =="
grep -n 'amfi->' "$X/iokit/bsddev/IOKitBSDInit.cpp" 2>/dev/null | head -20 >> "$OUT"

say
say "== 3. 这些 helper 的邻居（同文件 entitlement 家族）=="
grep -n 'extern "C".*Entitlement\|^IOTask\|^IOCurrent' "$X/iokit/bsddev/IOKitBSDInit.cpp" 2>/dev/null | head -20 >> "$OUT"

say
say "== 4. _amfi 结构体大小与 OSEntitlements 成员偏移 =="
sed -n '230,270p' "$X/libkern/libkern/amfi/amfi.h" >> "$OUT" 2>&1
grep -n -A22 'OSEntitlements;' "$X/libkern/libkern/amfi/amfi.h" 2>/dev/null | head -30 >> "$OUT"
say done
