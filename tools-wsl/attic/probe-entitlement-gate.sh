#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/entitlement-gate.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

say "== 1. IOTaskHasEntitlement 实现 =="
F=$(grep -rl 'IOTaskHasEntitlement' "$X" --include='*.cpp' --include='*.c' --include='*.h' 2>/dev/null | head -8)
echo "$F" >> "$OUT"
for f in $F; do
  say "-- $f --"
  grep -n -A22 'IOTaskHasEntitlement' "$f" | head -40 >> "$OUT" 2>&1
done

say
say "== 2. 谁在 boot 路径上调它（含 exec_init_process 附近）=="
grep -rn 'IOTaskHasEntitlement' "$X" --include='*.cpp' --include='*.c' 2>/dev/null | grep -v 'iokit/Kernel/IOKernelUtils' | head -15 >> "$OUT"
say done
