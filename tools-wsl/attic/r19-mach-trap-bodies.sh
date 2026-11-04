#!/bin/bash
# R 步之十二：走查件 mach 段要打的 9 发，先逐条读内核原文确认两件事——
# ① 参数顺序/宽度（munge_www 这类是 32 位字，指针参数别搞错）② 会不会阻塞。
# run-28 的教训就在这：一发阻塞的 trap 会把整条走查冻死，屏上再也读不到后面的。
set -u
LOG=/mnt/e/Code/HackIos/out/probes/r19-mach-trap-bodies.txt
: > "$LOG"
exec >> "$LOG" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work

echo "== 1. mach_msg：options=0（既不 send 也不 rcv）是否立刻返回 =="
grep -n "MACH_SEND_MSG\|MACH_RCV_MSG\|MACH_MSG_SUCCESS\|return" "$X/osfmk/ipc/mach_msg.c" | sed -n '1,40p'
echo "--- 头 80 行非注释 ---"
grep -vE '^\s*\*|^\s*/\*|^\s*$' "$X/osfmk/ipc/mach_msg.c" | sed -n '1,45p'

echo
echo "== 2. task_self / host_self / thread_self / reply 四个 0 参 trap 的返回契约 =="
for f in ipc/ipc_space.h kern/ipc_kern.c; do :; done
grep -rn "task_self_trap\|host_self_trap\|thread_self_trap\|mach_reply_port" "$X/osfmk" --include=*.c 2>/dev/null | grep -vE "syscall_sw|name_table|sleh" | head -12

echo
echo "== 3. _kernelrpc_mach_port_allocate_trap 参数（task, right, name*）=="
grep -rn -A18 "^_kernelrpc_mach_port_allocate_trap" "$X/osfmk/ipc/ipc_mqueue.c" "$X/osfmk/ipc/"*.c 2>/dev/null | head -30

echo
echo "== 4. mach_timebase_info_trap 出参结构 =="
grep -rn -A12 "mach_timebase_info_trap(" "$X/osfmk/kern/"*.c 2>/dev/null | head -25

echo
echo "== 5. arm_get_mach_syscall_args：64 位下参数从哪些寄存器取 =="
sed -n '85,140p' "$X/osfmk/arm64/bsd_arm64.c"

echo
echo "== 6. MACH_PORT_RIGHT_* 取值 =="
grep -rn "#define MACH_PORT_RIGHT_\(SEND\|RECEIVE\)" "$X/osfmk/mach/port.h" | head -4
echo "== done $(date -u +%FT%TZ)"
