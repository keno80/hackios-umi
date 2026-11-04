#!/bin/bash
# s1 里 arg 结构体没定位到。这棵树里 mach trap 的实参顺序 = C 原型顺序（arm_get_mach_syscall_args
# 按 x0..x(n-1) 原样 bcopy），所以直接读原型 + 表行注释里的参数个数，别猜。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s2-mach-prototypes.txt 2>&1
X=/home/unixnu/code/UniXNU-main/out/feeds/xnu-0b4b910d

echo "== 1. arg 结构体到底在哪 =="
grep -rln 'mach_msg_overwrite_args' "$X" 2>/dev/null | head -5

echo
echo "== 2. syscall_sw.c 里 10/12/14/31/32/47 六行 =="
grep -n 'MACH_TRAP((void *)_kernelrpc_mach_vm_allocate_trap\|vm_deallocate_trap\|vm_protect_trap\|_kernelrpc_mach_msg_trap\|mach_msg_overwrite_trap\|_kernelrpc_mach_msg2_trap\|mach_msg2\b' \
  "$X/osfmk/kern/syscall_sw.c" | head -20
echo "--- 表头注释（看每行格式）："
sed -n '95,125p' "$X/osfmk/kern/syscall_sw.c"

echo
echo "== 3. mach_msg 家族的用户态原型 =="
grep -rn -B6 'mach_msg_overwrite(\|mach_msg2_trap(\|^mach_msg_return_t$' "$X/osfmk/mach/mach.h" | head -60

echo
echo "== 4. vm 三发原型（mach.h 里的 kernelrpc 声明）=="
grep -rn -A8 'vm_allocate(\|vm_deallocate(\|vm_protect(' "$X/osfmk/mach/mach.h" | head -60

echo
echo "== 5. trap 实现里的 args 结构体字段（最终对齐依据）=="
grep -rn -A14 'kernelrpc_mach_vm_allocate_trap(' "$X/osfmk/mach/vm_mach.c" 2>/dev/null | head -30
echo "--- 找 vm_allocate trap 的实现文件："
grep -rln 'kernelrpc_mach_vm_allocate_trap' "$X/osfmk" | head -5

echo
echo "== 6. mach_msg 表项声明的 args 结构体名 =="
grep -rn 'MACH_IPC_DEPENDENT\|mach_msg_args\|vm_allocate_args' "$X/osfmk/kern/syscall_sw.h" | head -20
echo "== done $(date -u +%FT%TZ)"
