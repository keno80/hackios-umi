#!/bin/bash
# 精读 sys_fork 在 fork1 成功之后的那段（622 行 task_terminate_internal 是哪条错误路径），
# 并找子线程返回 EL0 的必经函数在本树里到底叫什么。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/m22-sysfork-body.txt
: > "$OUT"
exec >>"$OUT" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
F=$X/bsd/kern/kern_fork.c

echo "== 1. sys_fork 全文（540-680）=="
sed -n '540,680p' "$F" | nl -ba -v540

echo
echo "== 2. 子线程返回用户态的必经：全树搜 =="
for sym in machinecontextswitch set_childcontext act_set_state loadcontext machine_load_context; do
  printf '%-24s ' "$sym"
  grep -rl "$sym" $X/osfmk $X/bsd --include='*.c' --include='*.h' --include='*.S' 2>/dev/null | head -4 | tr '\n' ' '
  echo
done

echo
echo "== 3. arm64 里 set_childcontext / machinecontextswitch 的实现 =="
grep -rn 'set_childcontext' $X/osfmk/arm64/ 2>/dev/null | head -10

echo
echo "== 4. fork1 尾部（330-400）：child_thread 交给谁 =="
sed -n '330,400p' "$F" | nl -ba -v330

echo
echo "== 5. fork1 里 vm_task_setup / bsd_attach_task / 可能失败的步 =="
grep -n 'vm_fork\|vm_task_setup\|bsd_attach_task\|set_bsdtask_info\|proc_pid\|get_task_atmosphere\|if ((err = \|err = ' "$F" | sed -n '1,60p'

echo
echo "== 6. 真机/QEMU 面板最后几行的时间关系：子线程有没有被调度过 =="
grep -rn 'thread_start\|vm_thread_assume_stopped\|stopped' "$F" | head -20
echo "== done $(date -u +%FT%TZ)"
