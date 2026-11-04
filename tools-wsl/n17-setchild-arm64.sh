#!/bin/bash
# N 步之四：读 fork 子进程返回值的落地代码。
# 实测事实：run-25 里子进程 pid=2 走了 fixture 的父分支（cbz x0 没跳），说明它 fork 回来后 x0 != 0。
# kern_fork.c:363 传的是 proc_getpid(child_proc)，i386 版 thread_set_child 直接 rax=pid。
# 要看 arm64 版到底把 x0 写成什么，以及 fork1 里那行的注释语境。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/n17-setchild-arm64.txt
: > "$OUT"
exec >>"$OUT" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== 1. arm64 thread_set_child 全文（status.c:2030 起）=="
sed -n '2025,2085p' "$X/osfmk/arm64/status.c" | grep -n '' 

echo
echo "== 2. kern_fork.c 里那一行的上下文 330-400 =="
sed -n '330,400p' "$X/bsd/kern/kern_fork.c" | grep -n '' | sed 's/^/330+/'

echo
echo "== 3. set_user_saved_state_reg 宏 =="
grep -rn 'set_user_saved_state_reg' "$X/osfmk/arm64/saved_state.h" "$X/osfmk/arm/save_state.h" 2>/dev/null | head -6
H=$(grep -rl 'define set_user_saved_state_reg' "$X/osfmk" 2>/dev/null | head -1)
echo "HDR=$H"
[ -n "$H" ] && L=$(grep -n 'define set_user_saved_state_reg' "$H" | head -1 | cut -d: -f1) && sed -n "$((L-4)),$((L+8))p" "$H"

echo
echo "== 4. 谁还会把子进程 x0 归零（搜 fork 相关的 0 赋值）=="
grep -rn 'thread_set_child\|machine_set_child' "$X/bsd" "$X/osfmk" --include=*.c --include=*.h | grep -v i386 | head

echo
echo "== 5. task_wait_to_return 全文（子线程醒后走哪条路回 EL0）=="
F=$(grep -rl '^task_wait_to_return' "$X/osfmk" 2>/dev/null | head -1)
echo "FILE=$F"
L=$(grep -n '^task_wait_to_return' "$F" | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "$((L-8)),$((L+45))p" "$F"

echo
echo "== 6. 23z 探针在 arm64 哪个返回路径上打 EL0 OUT（解释子进程为何没有 OUT 行）=="
grep -n 'EL0 OUT\|EL0 IN' "$X/bsd/kern/kern_sigs.c" "$X/osfmk/arm64/slc_lockdown.c" "$X/bsd/sys/unix.c" 2>/dev/null | head
grep -rn 'EL0 OUT svc=' "$X" --include=*.c --include=*.h 2>/dev/null | head -4
echo done
