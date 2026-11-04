#!/bin/bash
# vm 三发的 arg 结构体不在 mach_traps.h 里（s4 第 2 段空手）。直接按符号名找声明与实现。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s5-vm-args.txt 2>&1
X=/home/unixnu/code/UniXNU-main/out/feeds/xnu-0b4b910d

echo "== 1. _kernelrpc_mach_vm_allocate_trap 出现在哪些文件 =="
grep -rln '_kernelrpc_mach_vm_allocate_trap' "$X/osfmk" 2>/dev/null | head

echo
echo "== 2. 声明（含参数顺序）=="
grep -rn -B6 -A12 '_kernelrpc_mach_vm_allocate_trap' "$X/osfmk/mach/vm.h" 2>/dev/null | head -40
grep -rn -A14 'struct vm_allocate_args' "$X/osfmk" 2>/dev/null | head -40

echo
echo "== 3. 实现体（看 copyout 宽度与 flags 校验）=="
F=$(grep -rl 'kernelrpc_mach_vm_allocate_trap(' "$X/osfmk" | grep -v syscall_sw | head -1)
echo "F=$F"
[ -n "$F" ] && grep -n -A40 'kernelrpc_mach_vm_allocate_trap(' "$F" | head -60

echo
echo "== 4. vm_deallocate / vm_protect 实现 =="
for s in _kernelrpc_mach_vm_deallocate_trap _kernelrpc_mach_vm_protect_trap; do
  echo "--- $s"
  G=$(grep -rl "$s(" "$X/osfmk" | grep -v syscall_sw | head -1)
  echo "G=$G"
  [ -n "$G" ] && grep -n -A26 "$s(" "$G" | head -40
done

echo
echo "== 5. port_insert_right 实现（确认 right 恒为 SEND、poly 语义）=="
H=$(grep -rl '_kernelrpc_mach_port_insert_right_trap(' "$X/osfmk" | grep -v syscall_sw | head -1)
echo "H=$H"
[ -n "$H" ] && grep -n -A30 '_kernelrpc_mach_port_insert_right_trap(' "$H" | head -45

echo
echo "== 6. 本档 IPC_HAS_LEGACY_MACH_MSG_TRAP 取哪条（ipc_policy.h:50-58）=="
sed -n '45,60p' "$X/osfmk/ipc/ipc_policy.h"
echo "== done $(date -u +%FT%TZ)"
