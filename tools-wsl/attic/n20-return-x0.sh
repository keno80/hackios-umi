#!/bin/bash
# N 步之七：子线程回 EL0 时 x0 由谁定——本地实现与上游 xnu 对照。
# 已知：thread_set_child 写 x0=pid（上游同），所以子进程拿到 0 必须发生在 bootstrap/return_from 路径；
#       run-25 实测子进程 x0 != 0。这里把这条路径的实现挖出来，并与上游逐字比。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/n20-return-x0.txt
: > "$OUT"
exec >>"$OUT" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== 1. thread_bootstrap_return 定义（全树搜函数体）=="
grep -rn 'thread_bootstrap_return' "$X/osfmk/kern/sched_prim.c" | head
L=$(grep -n '^thread_bootstrap_return' "$X/osfmk/kern/sched_prim.c" | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "$((L-12)),$((L+40))p" "$X/osfmk/kern/sched_prim.c" | grep -n ''

echo
echo "== 2. return_from_mach_traps / return_from_trap 在 sleh.c 的实现 =="
grep -n 'return_from_mach_traps\|return_from_unix_syscall64\|^return_from_trap\|static void.*return_from_trap' "$X/osfmk/arm64/sleh.c" | head
for FN in return_from_mach_traps return_from_unix_syscall64; do
  L2=$(grep -n "^$FN(" "$X/osfmk/arm64/sleh.c" | head -1 | cut -d: -f1)
  echo "-- $FN @ $L2 --"
  [ -n "$L2" ] && sed -n "$((L2-6)),$((L2+30))p" "$X/osfmk/arm64/sleh.c"
done

echo
echo "== 3. return_from_trap 本体（真正写 x0 的地方）=="
L3=$(grep -n 'return_from_trap(' "$X/osfmk/arm64/sleh.c" | tail -1 | cut -d: -f1)
grep -n 'return_from_trap' "$X/osfmk/arm64/sleh.c" | head
L4=$(grep -n '^return_from_trap' "$X/osfmk/arm64/sleh.c" | head -1 | cut -d: -f1)
[ -n "$L4" ] && sed -n "$((L4-8)),$((L4+40))p" "$X/osfmk/arm64/sleh.c" | grep -n ''

echo
echo "== 4. ith_state 的取值与 load_context 分支 =="
grep -rn 'MACHINE_CONTINUATION_RETURN\|MACHINE_STACK_CREATED\|ith_state' "$X/osfmk/arm64/machine_routines.c" "$X/osfmk/arm64/sbh.c" "$X/osfmk/kern/sched_prim.c" 2>/dev/null | head -12

echo
echo "== 5. 上游对照（xnu-12377.121.6）=="
for F in osfmk/kern/sched_prim.c osfmk/arm64/sleh.c; do
  O=/tmp/up-$(basename $F)
  if [ ! -s "$O" ]; then
    curl -sS -m 120 -H "Accept: application/vnd.github.raw+json" \
      "https://api.github.com/repos/apple-oss-distributions/xnu/contents/$F?ref=xnu-12377.121.6" -o "$O"
  fi
  echo "-- $F size=$(wc -c < "$O") --"
  head -c 200 "$O" | tr -d '\0' | grep -q 'No commit\|Not Found' && { echo "FETCH-FAIL"; continue; }
  echo "   [thread_bootstrap_return]"
  A=$(grep -n '^thread_bootstrap_return' "$O" | head -1 | cut -d: -f1)
  [ -n "$A" ] && sed -n "$((A-2)),$((A+34))p" "$O"
  echo "   [return_from_mach_traps]"
  B=$(grep -n '^return_from_mach_traps' "$O" | head -1 | cut -d: -f1)
  [ -n "$B" ] && sed -n "$((B-4)),$((B+18))p" "$O"
done

echo
echo "== 6. 本地 vs 上游：return_from_trap 里 x0 的写法逐字对照 =="
for SRC in "$X/osfmk/arm64/sleh.c" /tmp/up-sleh.c; do
  [ -f "$SRC" ] || continue
  echo "-- $SRC --"
  grep -n -A6 'saved_state64(state)->x\[0\] *=\|set_saved_state_reg(state, 0,' "$SRC" | head -20
done
echo done
