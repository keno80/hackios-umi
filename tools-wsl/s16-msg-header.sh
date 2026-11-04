#!/bin/bash
# S+1 前置取证（补 s15 没抠到的两处）：mach_msg 头的字段序 + overwrite/msg2 的原型。
# s15 的 grep 没命中的原因：mach_msg_header_t 不是具名 struct（typedef struct { ... } mach_msg_header_t），
# 而 overwrite 原型在 mach_msg.h 而不是 mach_traps.h。
# 为什么要现在抠：29z 的去重表按号各打一次，一次启动里「发一条 + 收一条」必须用两个不同的号，
# 号选错（比如 -47 在本档其实是 kern_invalid）就是白跑一轮。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s16-msg-header.txt 2>&1
X=/home/unixnu/code/UniXNU-main/out/feeds/xnu-0b4b910d

echo "== 1. mach_msg_header_t 定义（字段序 = 内存布局）=="
grep -n -B8 -A14 '} mach_msg_header_t;' "$X/osfmk/mach/message.h" | head -50

echo
echo "== 2. mach_msg 本体原型（7 参）与 overwrite（8 参）=="
grep -rn -A12 'kern_return_t mach_msg_overwrite_trap(' "$X/osfmk/mach/"*.h | head -40
grep -rn -A12 'kern_return_t mach_msg2(' "$X/osfmk/mach/mach_msg.h" | head -30

echo
echo "== 3. mach_msg2 的 option 位（64 位新接口，字段是 uint64）=="
grep -rn -B2 -A20 'MACH_MSG2_.*_MASK' "$X/osfmk/mach/mach_msg.h" | head -60

echo
echo "== 4. MACH_MSGH_BITS 宏本体（remote | local<<8）=="
grep -n -A6 'define MACH_MSGH_BITS(' "$X/osfmk/mach/message.h"
grep -n -A3 'define MACH_MSGH_BITS_REMOTE\|define MACH_MSGH_BITS_LOCAL' "$X/osfmk/mach/message.h" | head -20

echo
echo "== 5. trap 侧怎么把 x0..x7 喂给 overwrite（结构体参数表）=="
grep -n -B4 -A16 'struct _kernelrpc_mach_msg_overwrite_trap_args\|mach_msg_overwrite_trap_args' \
  "$X/osfmk/mach/mach_traps.h" "$X/osfmk/kern/syscall_sw.c" 2>/dev/null | head -50

echo
echo "== 6. 本档 47 号确实不是 kern_invalid：从编好的内核里查符号 =="
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho
source /usr/local/bin/unixnu-env 2>/dev/null
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
"$TC/CommandLineTools/usr/bin/nm" "$K" 2>/dev/null | grep -E 'mach_msg2_trap|mach_msg_overwrite_trap|mach_msg_trap$' | head
echo "== done =="
