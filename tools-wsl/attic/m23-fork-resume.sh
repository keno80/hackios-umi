#!/bin/bash
# #51 归因之二：fork 子线程到底被谁回收 / 有没有被恢复调度。
# 只读静态源码，为 25z 探针定落点。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/m23-fork-resume.txt
: > "$OUT"
exec >>"$OUT" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
F=$X/bsd/kern/kern_fork.c
E=$X/osfmk/kern
A=$X/osfmk/arm64

echo "== 1. fork 路径里谁把子线程唤醒 =="
grep -n 'thread_resume\|mach_thread_resume\|thread_set_runnable\|vm_thread_assume_stopped\|thread_start\|task_clear_return_wait\|set_threadreturn' "$F"
echo "-- thread_resume 在 cloneproc/create_new_thread 里的上下文 --"
grep -n -B6 -A10 'thread_resume' "$F" | head -60

echo
echo "== 2. create_new_thread 全文 =="
awk '/^create_new_thread/{f=1} f{print NR": "$0} f&&/^}/{c++; if(c>=1) exit}' "$F" | head -90

echo
echo "== 3. cloneproc 尾部（700-790）：p_stat=SRUN 之后 =="
sed -n '700,790p' "$F" | nl -ba -v700

echo
echo "== 4. fork1 前半（227-330） =="
sed -n '227,330p' "$F" | nl -ba -v227

echo
echo "== 5. thread_is_active 定义 + active 在哪被置起 =="
grep -rn 'thread_is_active' $E/*.h $E/*.c | head -10
grep -rn 'thread->active = \|t->active = \|->active = TRUE' $E/*.c | head -15

echo
echo "== 6. arm64 侧：thread_set_child / machine_load_context / call_result =="
grep -rn 'thread_set_child' $A/*.c $A/*.h $E/*.c $E/*.h 2>/dev/null | head -10
grep -rn -A12 '^thread_set_child' $A/pcb.c 2>/dev/null | head -30
grep -rn 'machine_load_context' $A/pcb.c 2>/dev/null | head -6

echo
echo "== 7. task_clear_return_wait 实现（它顺带 resume 吗） =="
grep -rn -A20 'task_clear_return_wait(' $E/ipc_mare_blacklist.c $E/task.c 2>/dev/null | head -40

echo
echo "== 8. wait4 的两处 ECHILD 上下文 =="
sed -n '3105,3130p' $X/bsd/kern/kern_exit.c | nl -ba -v3105
echo "----"
sed -n '3385,3405p' $X/bsd/kern/kern_exit.c | nl -ba -v3385

echo
echo "== 9. 子进程回收：exit 里把 child 从 p_children 摘掉的地方 =="
sed -n '2855,2880p' $X/bsd/kern/kern_exit.c | nl -ba -v2855
echo "== done $(date -u +%FT%TZ)"
