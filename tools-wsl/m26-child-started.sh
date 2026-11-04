#!/bin/bash
# 并行侦察：fork 出来的子线程，谁把 started 置起 / 谁把它放上运行队列。
# kern_fork.c 里 thread_resume / thread_set_runnable / thread_start 全部命中 0（m23 已证），
# 那这条线程的点火只能发生在 vm_thread_setup 或 machine_load_context 里。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/m26-child-started.txt
: > "$OUT"
exec >>"$OUT" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== 1. started = TRUE 的站点 =="
grep -rn 'started = TRUE' $X/osfmk/kern/*.c $X/osfmk/arm64/*.c 2>/dev/null | head -12

echo
echo "== 2. thread_set_runnable 定义与调用者 =="
grep -rn 'thread_set_runnable' $X/osfmk $X/bsd --include='*.c' --include='*.h' 2>/dev/null | head -12

echo
echo "== 3. machine_load_context 定义在哪 =="
grep -rn '^machine_load_context' $X --include='*.c' 2>/dev/null | head -5

echo
echo "== 4. vm_thread_setup 全文 =="
grep -rn '^vm_thread_setup' $X --include='*.c' 2>/dev/null | head -3
F=$(grep -rln '^vm_thread_setup' $X --include='*.c' 2>/dev/null | head -1)
echo "FILE=$F"
[ -n "$F" ] && awk '/^vm_thread_setup/{f=1} f{print NR": "$0} f&&/^}$/{exit}' "$F" | head -70

echo
echo "== 5. fork_create_child 尾部：new_thread 交出去之前做了什么 =="
grep -n 'fork_create_child' $X/bsd/kern/kern_fork.c | head -4
sed -n '440,540p' $X/bsd/kern/kern_fork.c | nl -ba -v440

echo
echo "== 6. start_of_thread（startup.c）等 started 的那段 =="
awk '/^start_of_thread/{f=1} f{print NR": "$0} f&&/^}$/{exit}' $X/osfmk/kern/startup.c | head -60
echo "== done $(date -u +%FT%TZ)"
