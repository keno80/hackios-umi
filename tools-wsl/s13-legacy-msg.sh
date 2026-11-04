#!/bin/bash
# S+1 取证：本档到底走不走 legacy mach_msg_trap。
# 为什么要查：29z 的去重表按 trap 号各打一次，-31 已经打过了；
# S+1 要「真收发一条消息」必须换一个没打过的号（-32 overwrite 或 -47 msg2），
# 而换哪个号取决于本档启不启用 legacy 分支——这由 IPC_HAS_LEGACY_MACH_MSG_TRAP 决定。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s13-legacy-msg.txt 2>&1
X=/home/unixnu/code/UniXNU-main/out/feeds/xnu-0b4b910d

echo "== 1. 宏定义处（ipc_policy.h）=="
grep -n -B4 -A8 'define IPC_HAS_LEGACY_MACH_MSG_TRAP' "$X/osfmk/ipc/ipc_policy.h"

echo
echo "== 2. 谁在用这个宏（所有命中）=="
grep -rn 'IPC_HAS_LEGACY_MACH_MSG_TRAP' "$X/osfmk" "$X/bsd" 2>/dev/null

echo
echo "== 3. mach_msg 三兄弟在 trap 表里的行（号 + 参数数 + munge 串）=="
grep -n -A3 'MACH_TRAP(mach_msg' "$X/osfmk/mach/arm/syscall_sw.c" 2>/dev/null \
  || grep -rn -A3 'MACH_TRAP(mach_msg' "$X/osfmk/kern/syscall_sw.c"

echo
echo "== 4. 表下标就是负号的绝对值：把三行周围的号对齐打出来 =="
grep -n 'MACH_TRAP' "$X/osfmk/kern/syscall_sw.c" 2>/dev/null | sed -n '1,60p'

echo
echo "== 5. arm_get_mach_syscall_args 的取参宽度（决定 x0..x7 够不够）=="
grep -n -A25 'arm_get_mach_syscall_args' "$X/osfmk/arm/syscall.m" 2>/dev/null | head -60

echo "== done =="
