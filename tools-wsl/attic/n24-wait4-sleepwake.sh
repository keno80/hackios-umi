#!/bin/bash
# P 步之一：run-26 屏到 REAP cpid=2 就停，父进程 wait4 再没回 EL0。
# 先把 REAP 探针的宿主函数、wait4 的睡眠/唤醒与成功返回点看清。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/n24-wait4-sleepwake.txt
: > "$OUT"
exec >>"$OUT" 2>&1

X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work/bsd/kern/kern_exit.c

echo "== 1. REAP 锚点所在函数 =="
A=$(grep -n 'pgrp_leave_locked(child)' "$X" | head -3)
echo "$A"
L=$(echo "$A" | head -1 | cut -d: -f1)
echo "-- 往上找最近的函数头 --"
awk -v target="$L" 'NR<=target && /^[a-zA-Z_].*\(/ {fn=NR": "$0} END{print fn}' "$X"
grep -n '^[a-zA-Z_].*(' "$X" | awk -v t="$L" -F: '$1<t' | tail -3

echo
echo "== 2. REAP 前后 60 行 =="
sed -n "$((L-30)),$((L+40))p" "$X" | grep -n '' | sed "s/^/  /"

echo
echo "== 3. wait4_nocancel 全文行号范围 =="
grep -n 'wait4_nocancel\|waitid_nocancel\|wait_nocancel' "$X" | head -20

echo
echo "== 4. wait4 里的睡眠点与唤醒条件 =="
grep -n 'thread_block\|tsleep\|sleep_with_timeout\|WANT_CHILD\|child_is_zombie\|p_wchan\|ast' "$X" | head -40

echo
echo "== 5. proc_reapchild / reap 相关函数定义 =="
grep -n 'proc_reapchild\|reap_child\|process_should_mark_exec_failed' "$X" | head -20

echo
echo "== 6. exit1 里唤醒父进程的那一段 =="
grep -n 'wake\|WANT_CHILD\|tsleep' "$X" | grep -in 'wake' | head -20
echo done
