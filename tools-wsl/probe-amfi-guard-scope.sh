#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/amfi-guard-scope.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
F=/home/unixnu/code/UniXNU-main/out/feeds/xnu-0b4b910d

say "== 1. 上游已有的 amfi NULL 守卫 =="
grep -rn 'amfi == NULL\|amfi != NULL\|if (amfi)' "$X" --include='*.c' --include='*.cpp' 2>/dev/null | head -20 >> "$OUT"
say "-- 计数 --"
grep -rc 'amfi == NULL' "$X/bsd/kern/ubc_subr.c" "$X/bsd/kern/kern_cs.c" "$X/bsd/kern/kern_trustcache.c" "$X/bsd/vm/vm_unix.c" 2>/dev/null >> "$OUT"

say
say "== 2. feeds 里的原件是否存在且与 xnu-work 一致 =="
ls -l "$F/iokit/bsddev/IOKitBSDInit.cpp" 2>/dev/null >> "$OUT"
diff -q "$F/iokit/bsddev/IOKitBSDInit.cpp" "$X/iokit/bsddev/IOKitBSDInit.cpp" 2>&1 | head -3 >> "$OUT"

say
say "== 3. 三个站点的精确上下文（1581-1600 / 1612-1632 / 1642-1662）=="
sed -n '1581,1600p' "$X/iokit/bsddev/IOKitBSDInit.cpp" >> "$OUT" 2>&1
say "..."
sed -n '1612,1632p' "$X/iokit/bsddev/IOKitBSDInit.cpp" >> "$OUT" 2>&1
say "..."
sed -n '1642,1662p' "$X/iokit/bsddev/IOKitBSDInit.cpp" >> "$OUT" 2>&1
say done
