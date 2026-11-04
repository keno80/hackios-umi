#!/bin/bash
# #51 归因之四：静态坐实「init 那条线程到底 active 不 active」，并取 25z 探针的精确锚点。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/m25-active-anchor.txt
: > "$OUT"
exec >>"$OUT" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
E=$X/osfmk/kern

echo "== 1. 全树给 thread->active 置 TRUE 的站点 =="
grep -rn 'active = TRUE' $E/*.c | head -20
echo "-- 1559 所在函数（往上找第一个第 0 列非空行）--"
awk 'NR<=1559 && /^[A-Za-z_].*\(/{last=NR": "$0} END{print last}' $E/thread.c
awk 'NR<=1559 && /^[A-Za-z_]/{print NR": "$0}' $E/thread.c | tail -4

echo
echo "== 2. kernel_thread_create 走不走 create_thread =="
grep -n 'kernel_thread_create_internal\|^create_thread\|create_thread(' $E/thread.c | head -20

echo
echo "== 3. init 的用户线程是谁：bsd_init 里 load_init_program 前后 =="
grep -n 'load_init_program\|act_set_state\|machinecontextswitch\|p->p_flag\|utask\|kernel_thread' $X/bsd/kern/bsd_init.c | sed -n '1,40p'

echo
echo "== 4. kern_fork.c / kern_exit.c 能否直接用 boot_progress_stage =="
for f in $X/bsd/kern/kern_fork.c $X/bsd/kern/kern_exit.c; do
  echo "-- $f"
  grep -n '#include <osfmk/kern/boot_progress.h>\|#include "osfmk/kern/boot_progress.h"\|boot_progress.h\|#include <kern/thread.h>\|snprintf' "$f" | head -8
done

echo
echo "== 5. 锚点原文（cat -A 看制表符）=="
echo "-- 5a fork() 里 retval[0] 那两行 --"
sed -n '582,586p' $X/bsd/kern/kern_fork.c | cat -A | sed 's/\$$/<EOL>/'
echo "-- 5b deadparent 分支 --"
sed -n '617,627p' $X/bsd/kern/kern_fork.c | cat -A | sed 's/\$$/<EOL>/'
echo "-- 5c task_clear_return_wait 那三行 --"
sed -n '628,634p' $X/bsd/kern/kern_fork.c | cat -A | sed 's/\$$/<EOL>/'
echo "-- 5d kern_exit.c ECHILD@3395-3400 --"
sed -n '3393,3401p' $X/bsd/kern/kern_exit.c | cat -A | sed 's/\$$/<EOL>/'
echo "-- 5e kern_exit.c 回收处 2863-2876 --"
sed -n '2861,2876p' $X/bsd/kern/kern_exit.c | cat -A | sed 's/\$$/<EOL>/'
echo "-- 5f 5e 所在函数名 --"
awk 'NR<=2867 && /^[A-Za-z_].*\(/{last=NR": "$0} END{print last}' $X/bsd/kern/kern_exit.c
echo "== done $(date -u +%FT%TZ)"
