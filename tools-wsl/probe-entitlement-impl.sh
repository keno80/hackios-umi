#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/entitlement-impl.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

say "== 1. 实现（IOBSD.cpp）=="
grep -rn -A30 '^IOTaskHasEntitlement' "$X/iokit/Kernel/IOBSD.cpp" 2>/dev/null | head -45 >> "$OUT"

say
say "== 2. kern_exec.c 里的调用点 =="
grep -n -B6 -A4 'IOTaskHasEntitlement' "$X/bsd/kern/kern_exec.c" 2>/dev/null | head -60 >> "$OUT"

say
say "== 3. mac_proc_check_get_task / AMFI 侧的 entitlement 取值 =="
grep -rn 'mac_task_get_query_entitlement\|AMFIQueryTaskEntitlement\|amfi_task_has_entitlement' "$X/bsd/" "$X/iokit/" 2>/dev/null | head -12 >> "$OUT"
say done
