#!/bin/bash
# 并行侦察之二：子线程的出生函数 main_thread_create_waiting 与它要等的 task_wait_to_return。
# 关键问题：谁把这条线程放上运行队列（started/thread_run），否则 task_clear_return_wait 唤不醒一条从未跑起来的线程。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/m27-main-thread-create.txt
: > "$OUT"
exec >>"$OUT" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
E=$X/osfmk/kern

echo "== 1. main_thread_create_waiting 定义 =="
grep -rn 'main_thread_create_waiting' $X --include='*.c' --include='*.h' | head -8
F=$(grep -rln '^main_thread_create_waiting' $X --include='*.c' | head -1)
echo "FILE=$F"
[ -n "$F" ] && awk '/^main_thread_create_waiting/{f=1} f{print NR": "$0} f&&/^}$/{exit}' "$F"

echo
echo "== 2. thread_create_waiting 实现 =="
F2=$(grep -rln '^thread_create_waiting' $X --include='*.c' | head -1)
echo "FILE=$F2"
[ -n "$F2" ] && awk '/^thread_create_waiting/{f=1} f{print NR": "$0} f&&/^}$/{exit}' "$F2"

echo
echo "== 3. task_wait_to_return 实现 =="
F3=$(grep -rln '^task_wait_to_return' $X --include='*.c' | head -1)
echo "FILE=$F3"
[ -n "$F3" ] && awk '/^task_wait_to_return/{f=1} f{print NR": "$0} f&&/^}$/{exit}' "$F3"

echo
echo "== 4. thread_act.c:176 / :225 所在函数 =="
sed -n '160,232p' $E/thread_act.c | nl -ba -v160

echo
echo "== 5. arm64 的 machine_load_context 到底在哪 =="
grep -rn 'machine_load_context' $X/osfmk/arm64/ $X/osfmk/arm/ 2>/dev/null | head -8

echo
echo "== 6. 谁调用 thread_start_internal（普通线程点火入口）=="
grep -rn 'thread_start_internal' $X/osfmk $X/bsd --include='*.c' 2>/dev/null | head -10
echo "== done $(date -u +%FT%TZ)"
