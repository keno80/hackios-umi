#!/bin/bash
# R 步之十三：r19 确认 64 位下参数就是 x0..x(n-1) 直取、port_allocate 要 target=自己的 task port、
# timebase 只 copyout 8 字节。剩最后一个未知：mach_msg 在 option=0 时到底立刻返回还是阻塞。
# 这发决定走查件 mach 段最后一发能不能打——run-28 就是被一发阻塞的 trap 冻死的。
set -u
LOG=/mnt/e/Code/HackIos/out/probes/r20-mach-msg-nonblock.txt
: > "$LOG"
exec >> "$LOG" 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
M=$X/osfmk/ipc/mach_msg.c

echo "== 1. 参数校验函数（405..515）=="
sed -n '405,515p' "$M"

echo
echo "== 2. mach_msg_overwrite_trap 主体：找 option 位判定与阻塞点 =="
grep -n "mach_msg_overwrite_trap\|mach_msg_trap\|MACH_RCV_MSG\|MACH_SEND_MSG\|thread_block\|options ==" "$M" | head -30

echo
echo "== 3. task_self_trap 主体（1347..1395）=="
sed -n '1347,1395p' "$X/osfmk/kern/ipc_tt.c"

echo
echo "== 4. host_self_trap 主体（157..200）=="
sed -n '157,200p' "$X/osfmk/kern/ipc_host.c"
echo "== done $(date -u +%FT%TZ)"
