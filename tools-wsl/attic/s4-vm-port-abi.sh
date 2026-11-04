#!/bin/bash
# S 步取证：要加 vm_allocate(-10)/vm_protect(-14)/vm_deallocate(-12)/mach_port_insert_right(-21) 四发。
# 64 位下参数就是 x0..x(n-1) 原样 bcopy，但「指针出参写 4 字节还是 8 字节」必须看结构体，猜错就读到脏值。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s4-vm-port-abi.txt 2>&1
X=/home/unixnu/code/UniXNU-main/out/feeds/xnu-0b4b910d
B=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/fakeroot/usr/include

echo "== 1. 表行 21（port_insert_right）=="
grep -n '^/\* 21 \*/' "$X/osfmk/kern/syscall_sw.c"

echo
echo "== 2. vm 三发的 trap 原型（mach_traps.h）=="
for f in "$X/osfmk/mach/mach_traps.h" "$B/mach/mach_traps.h"; do
  [ -f "$f" ] || continue
  echo "--- $f"
  grep -n -B3 -A10 'vm_allocate(\|vm_deallocate(\|vm_protect(' "$f" | head -60
done

echo
echo "== 3. port_insert_right 原型与 right/type 取值 =="
grep -rn -B3 -A10 'mach_port_insert_right' "$X/osfmk/mach/port.h" | head -40
echo "--- MACH_PORT_RIGHT_SEND 内核索引值（本树 port.h:270 附近）："
sed -n '262,300p' "$X/osfmk/mach/port.h"

echo
echo "== 4. trap 实现体：出参 copyout 的宽度 =="
echo "--- vm_allocate："
grep -rn -A30 '_kernelrpc_mach_vm_allocate_trap' "$X/osfmk/mach/vm_mach.c" | sed -n '1,45p'
echo "--- port_insert_right："
grep -rn -A25 '_kernelrpc_mach_port_insert_right_trap' "$X/osfmk/ipc/ipc_mach.c" 2>/dev/null | sed -n '1,35p'
F=$(grep -rl '_kernelrpc_mach_port_insert_right_trap' "$X/osfmk" | head -1); echo "F=$F"

echo
echo "== 5. IPC_HAS_LEGACY_MACH_MSG_TRAP 在嵌入式上开不开（决定 S+1 用 32 还是 47）=="
grep -rn 'define IPC_HAS_LEGACY_MACH_MSG_TRAP' "$X/osfmk" | head -5
grep -rn -B4 -A8 'define IPC_HAS_LEGACY_MACH_MSG_TRAP' "$X/osfmk/ipc/ipc_kmsg.h" 2>/dev/null | head -30

echo
echo "== 6. mach_msg_overwrite_trap_args 字段（S+1 备用）=="
grep -rn -A14 'struct mach_msg_overwrite_trap_args' "$X/osfmk" 2>/dev/null | head -30
echo "== done $(date -u +%FT%TZ)"
