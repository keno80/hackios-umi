#!/bin/bash
# N 步之六：找「子线程回 EL0 时 x0 由谁定」的实现，本地与上游对照。
# 已知：上游 thread_set_child 也写 x0=pid，所以真机上子进程拿到 0 必然发生在另一条路径上；
#       run-25 实测子进程 x0 != 0（没走 fixture 的 _child 分支）。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/n19-bootstrap-return.txt
: > "$OUT"
exec >>"$OUT" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== 1. thread_bootstrap_return 定义在哪 =="
grep -rn 'thread_bootstrap_return' "$X/osfmk" --include=*.c --include=*.h | head -12

echo
echo "== 2. 本地定义全文 =="
F=$(grep -rl '^thread_bootstrap_return' "$X/osfmk" --include=*.c | head -1)
echo "FILE=$F"
L=$(grep -n '^thread_bootstrap_return' "$F" | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "$((L-10)),$((L+45))p" "$F" | grep -n ''

echo
echo "== 3. return_from_mach_traps / return_from_unix_syscall64 的定义与 x0 落地 =="
grep -rn 'return_from_mach_traps\|return_from_unix_syscall64\|return_from_trap' "$X/osfmk/arm64/"*.c "$X/osfmk/arm64/*.s" 2>/dev/null | head -14
grep -rn 'void __attribute__((noreturn))$\|noreturn)) *$' "$X/osfmk/arm64/sleh.c" | head -8

echo
echo "== 4. sleh.c 里给 EL0 写返回值的地方（set_saved_state_reg(..., 0, ...)）=="
grep -n 'set_saved_state_reg(state, 0\|set_user_saved_state_reg(state, 0\|set_saved_state_reg_index(state, 0' "$X/osfmk/arm64/sleh.c" | head -12

echo
echo "== 5. 23z 的 EL0 IN/OUT 探针在 sleh.c 的哪两个函数里 =="
L1=$(grep -n 'EL0 IN svc=' "$X/osfmk/arm64/sleh.c" | head -1 | cut -d: -f1)
L2=$(grep -n 'EL0 OUT svc=' "$X/osfmk/arm64/sleh.c" | head -1 | cut -d: -f1)
echo "IN@$L1 OUT@$L2"
for L in $L1 $L2; do
  [ -n "$L" ] && { echo "-- 附近 --"; sed -n "$((L-18)),$((L+8))p" "$X/osfmk/arm64/sleh.c"; }
done

echo
echo "== 6. 上游对照：main_thread_create_waiting 全文 =="
F2=$(grep -rl '^main_thread_create_waiting' "$X/bsd" "$X/osfmk" --include=*.c 2>/dev/null | head -1)
echo "FILE=$F2"
L3=$(grep -n '^main_thread_create_waiting' "$F2" | head -1 | cut -d: -f1)
[ -n "$L3" ] && sed -n "$((L3-14)),$((L3+55))p" "$F2" | grep -n ''
echo done
