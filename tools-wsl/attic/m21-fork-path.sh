#!/bin/bash
# 下一刀侦察：fork 返了 pid，子进程却从没发过 svc（面板无 IN svc=1），wait4 得 ECHILD。
# 目标：找出「子线程从 fork1 到返回 EL0」的必经函数链，以及中途哪些失败路径会静默回收子进程。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/m21-fork-path.txt
: > "$OUT"
exec >>"$OUT" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== 1. sys_fork / fork1 入口与返回 =="
F=$X/bsd/kern/kern_fork.c
ls -la "$F"
grep -n '^fork1\|^sys_fork\|^static.*fork1\|fork1(\|return (.\|proc_free\|thread_deallocate\|machinecontextswitch\|act_set_state\|loadcontext\|terminate' "$F" | head -60

echo
echo "== 2. fork1 里所有错误出口（goto / return error）带上下文 =="
grep -n -B3 -A6 'out:\|bad:\|goto out' "$F" | head -80

echo
echo "== 3. 子进程返回用户态的必经：machinecontextswitch / act_set_state =="
grep -rn 'machinecontextswitch' $X/osfmk/arm64/*.c $X/osfmk/arm/*.c 2>/dev/null | head -10
grep -rn 'void machinecontextswitch' $X --include='*.c' 2>/dev/null | head -5

echo
echo "== 4. machinecontextswitch 实现体 =="
for f in $(grep -rl 'machinecontextswitch' $X/osfmk --include='*.c' 2>/dev/null | head -6); do
  echo "---- $f"
  awk '/^machinecontextswitch|^[a-z_]* *$/{} /machinecontextswitch\(void/{p=1} p{print NR": "$0} p&&/^}/{exit}' "$f" | head -50
done

echo
echo "== 5. ECHILD 从哪来（wait4 无子） =="
grep -rn 'ECHILD' $X/bsd/kern/kern_exit.c | head -20

echo
echo "== 6. wait4 判定「有没有子」的字段 =="
grep -n 'p_children\|children_left\|waited_children\|session_lowest_pid' $X/bsd/kern/kern_exit.c | head -30

echo
echo "== 7. fork1 尾部：子线程是否被显式启动 =="
tail -80 "$F"

echo
echo "== 8. 现有 amfi 守卫是否覆盖 fork 路径 =="
grep -n 'IOTaskHasEntitlement\|amfi' "$F" | head -20
echo "== done $(date -u +%FT%TZ)"
