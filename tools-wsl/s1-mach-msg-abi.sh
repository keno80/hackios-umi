#!/bin/bash
# S 步取证：要把走查件从「option=0 的 mach_msg」推到「真收发一次」，先钉死三件事——
# (1) mach_msg / mach_msg_overwrite 的参数结构与顺序；(2) option 位与 header bits 的宏；
# (3) vm_allocate/vm_protect/vm_deallocate 的参数结构与 flags。
# 只认这棵树里构建出来的那份定义，别按 Darwin 记忆写。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s1-mach-msg-abi.txt 2>&1
X=/home/unixnu/code/UniXNU-main/out/feeds/xnu-0b4b910d

echo "== 1. arg 结构体定义在哪 =="
grep -rln 'struct mach_msg_overwrite_args\|struct mach_msg_args' "$X/osfmk" 2>/dev/null | head

echo
echo "== 2. mach_msg_args / overwrite_args 全文 =="
grep -rn -A16 'struct mach_msg_args$' "$X/osfmk/mach/mach_traps.h" 2>/dev/null | head -40
grep -rn -A20 'struct mach_msg_overwrite_args' "$X/osfmk/mach/mach_traps.h" 2>/dev/null | head -50
echo "--- 若上面空，按文件找："
F=$(grep -rl 'struct mach_msg_overwrite_args' "$X/osfmk" | head -1); echo "F=$F"
[ -n "$F" ] && grep -n -B2 -A22 'struct mach_msg_args' "$F" | head -70

echo
echo "== 3. option 位（MACH_SEND_MSG / MACH_RCV_MSG / MACH_RCV_TIMEOUT / MACH_SEND_TIMEOUT）=="
grep -rn 'define MACH_SEND_MSG\b\|define MACH_RCV_MSG\b\|define MACH_RCV_TIMEOUT\|define MACH_SEND_TIMEOUT\|define MACH_RCV_LARGE\b' \
  "$X/osfmk/mach/message.h" | head -20

echo
echo "== 4. mach_msg_header_t 字段顺序与大小 =="
grep -n -B4 -A14 'typedef struct mach_msg_header' "$X/osfmk/mach/message.h" | head -50
echo "--- MACH_MSGH_BITS 宏："
grep -n -A6 'define MACH_MSGH_BITS(' "$X/osfmk/mach/message.h" | head -20
echo "--- descriptor 类型值："
grep -n 'MACH_MSG_PORT_DESCRIPTOR\|MACH_MSGOOL\|MACH_MSG_TYPE_COPY_SEND\|MACH_MSG_TYPE_MAKE_SEND\b\|MACH_MSG_TYPE_MOVE_SEND\b' \
  "$X/osfmk/mach/message.h" | head -20

echo
echo "== 5. 表里 31/32/47 三行的原型（决定实参个数）=="
grep -n -A3 'mach_msg)\|mach_msg_overwrite)\|mach_msg2)' "$X/osfmk/kern/syscall_sw.c" | head -40

echo
echo "== 6. vm 三发的参数结构 =="
grep -rn -A10 'struct vm_allocate_args\|struct vm_protect_args\|struct vm_deallocate_args' \
  "$X/osfmk/mach/vm_traps.h" 2>/dev/null | head -60
echo "--- vm_traps.h 在不在："
ls -la "$X/osfmk/mach/vm_traps.h" 2>&1
echo "--- VM_FLAGS_*："
grep -n 'define VM_FLAGS_ANYWHERE\|define VM_FLAGS_FIXED\|define VM_PROT_READ\|define VM_PROT_WRITE\|define VM_PROT_ALL' \
  "$X/osfmk/mach/vm_prot.h" "$X/osfmk/mach/vm_statistics.h" 2>/dev/null | head -20

echo
echo "== 7. mach_msg 内核侧对 rcv_size/timeout 的硬要求（会不会 assert）=="
grep -rn -A12 'MACH_RCV_MSG)' "$X/osfmk/ipc/mach_msg.c" 2>/dev/null | head -40
grep -rn 'mach_msg_timeout_t\|MACH_MSG_UNLIMITED' "$X/osfmk/mach/message.h" | head -10
echo "== done $(date -u +%FT%TZ)"
