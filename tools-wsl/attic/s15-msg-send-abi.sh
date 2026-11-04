#!/bin/bash
# S+1 前置取证：真收发一条 mach_msg 要用哪个号、参数怎么摆。
# 为什么必须换号：29z 的去重表按 trap 号各打一次，-31 在 R 步已经打过，
#   同一次启动里第二次调 -31 不会上屏——发一条收一条至少要两个号。
# 本文件要回答三件事：
#   1) 表里 47 号(mach_msg2)在本档到底是不是 kern_invalid（取决于 153 行那个 #if 走哪条）；
#   2) 32 号(mach_msg_overwrite)的原型与 8 个参数顺序；
#   3) 本树 ipc_policy.c 的 legacy 开关在 iOS target 下取 1 还是 0。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s15-msg-send-abi.txt 2>&1
X=/home/unixnu/code/UniXNU-main/out/feeds/xnu-0b4b910d

echo "== 1. syscall_sw.c 里 47 号那行的 #if 条件 =="
grep -n -B12 '/\* 47 \*/ MACH_TRAP(mach_msg2_trap' "$X/osfmk/kern/syscall_sw.c" | tail -20
echo "--- 它的 #else/#endif 上下文："
sed -n '150,160p' "$X/osfmk/kern/syscall_sw.c"

echo
echo "== 2. 该 #if 用到的宏在本树的定义 =="
grep -rn 'define MACH_MSG2_TRAP\|IPC_HAS_MACH_MSG2_TRAP\|MACH_TRAP_TABLE_COUNT' \
  "$X/osfmk/mach" "$X/osfmk/kern" 2>/dev/null | head -12

echo
echo "== 3. mach_msg_overwrite_trap 的原型（实参顺序 = x0..x7）=="
grep -n -A14 'kern_return_t mach_msg_overwrite_trap' "$X/osfmk/mach/mach_traps.h" | head -40

echo
echo "== 4. mach_msg_trap 的原型（对照）=="
grep -n -A12 'kern_return_t mach_msg_trap' "$X/osfmk/mach/mach_traps.h" | head -30

echo
echo "== 5. option 位与 MACH_MSGH_BITS 的取值（发+收各要哪些位）=="
grep -nE 'define MACH_SEND_MSG |define MACH_RCV_MSG |define MACH_RCV_LARGE |define MACH_SEND_TIMEOUT |define MACH_RCV_TIMEOUT ' \
  "$X/osfmk/mach/message.h"
grep -nE 'define MACH_MSG_TYPE_MOVE_SEND |define MACH_MSG_TYPE_COPY_SEND |define MACH_MSG_TYPE_MAKE_SEND |define MACH_MSGH_BITS_REMOTE |define MACH_MSGH_BITS_LOCAL |define MACH_MSGH_BITS_COMPLEX ' \
  "$X/osfmk/mach/message.h"

echo
echo "== 6. legacy 开关在 iOS 下的实际取值：本档编的是哪个 target =="
grep -rn 'XNU_TARGET_OS_IOS' "$X/osfmk/ipc/ipc_policy.h" | head
echo "--- 本树里 XNU_TARGET_OS_IOS 怎么来的（构建侧）："
grep -rn 'XNU_TARGET_OS_IOS' /home/unixnu/code/UniXNU-main/scripts 2>/dev/null | head -8

echo
echo "== 7. 一条最小合法消息长什么样（mach_msg_header_t 字段序）=="
grep -n -A12 'typedef struct mach_msg_header' "$X/osfmk/mach/message.h" | head -30

echo "== done =="
