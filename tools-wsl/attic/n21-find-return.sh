#!/bin/bash
# N 步之八：把 thread_bootstrap_return / return_from_* 的真实落点找出来并读体。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/n21-find-return.txt
: > "$OUT"
exec >>"$OUT" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== 1. thread_bootstrap_return 的定义体（全 osfmk 宽搜）=="
grep -rn 'thread_bootstrap_return' "$X/osfmk" --include=*.c --include=*.h --include=*.S | grep -v 'thread_create\|continuation' | head
for f in $(grep -rl 'thread_bootstrap_return' "$X/osfmk" --include=*.c | head -4); do
  echo "-- $f --"
  grep -n -A28 'thread_bootstrap_return(void)$' "$f" | head -40
done

echo
echo "== 2. return_from_* 系列在 arm64 的落点 =="
grep -rn 'return_from_mach_traps\|return_from_unix_syscall64\|return_from_trap' "$X/osfmk/arm64" "$X/osfmk/arm" 2>/dev/null | grep -v Binary | head -20

echo
echo "== 3. sleh.c 里 noreturn 的函数都有哪些 =="
grep -n -B3 '__attribute__((noreturn))' "$X/osfmk/arm64/sleh.c" | grep -A3 'noreturn' | head -40
grep -n '^static void\|^void\|^__attribute__' "$X/osfmk/arm64/sleh.c" | sed -n '1,1p'
awk '/__attribute__\(\(noreturn\)\)/{f=1} f && /^[a-z_]+\(/ {print NR": "$0; f=0}' "$X/osfmk/arm64/sleh.c" | head -12

echo
echo "== 4. 上游同项对照（已抓到的两份）=="
for O in /tmp/up-sched_prim.c /tmp/up-sleh.c; do
  echo "-- $O --"
  [ -s "$O" ] || { echo EMPTY; continue; }
  grep -n 'thread_bootstrap_return\|return_from_mach_traps\|return_from_unix_syscall64\|return_from_trap' "$O" | head -12
done

echo
echo "== 5. 上游 thread_bootstrap_return 体 =="
A=$(grep -n 'thread_bootstrap_return(void)$' /tmp/up-sched_prim.c | head -1 | cut -d: -f1)
echo "@$A"
[ -n "$A" ] && sed -n "$((A-10)),$((A+40))p" /tmp/up-sched_prim.c
echo done
