#!/bin/bash
# 表行说 mach_msg_overwrite_trap 是 8 个参数，但 arg 结构体没定位到——
# 它在 <mach/mach_traps.h> 里，这棵树里不一定放在 osfmk/mach 下。找到它、把三发要用的结构体抄全。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s3-mach-traps-h.txt 2>&1
X=/home/unixnu/code/UniXNU-main/out/feeds/xnu-0b4b910d

echo "== 1. mach_traps.h 在哪 =="
find "$X" -name 'mach_traps.h' 2>/dev/null | head -5
find /home/unixnu/code/umi-work-pin -name 'mach_traps.h' 2>/dev/null | head -5

echo
echo "== 2. 表行 10/31/47（补全）=="
grep -n '^/\* \(10\|31\|47\) \*/' "$X/osfmk/kern/syscall_sw.c"

echo
echo "== 3. 结构体全文（找到文件后打印）=="
H=$(find "$X" -name 'mach_traps.h' | head -1)
echo "H=$H"
if [ -n "$H" ]; then
  grep -n -A12 'struct mach_msg_args\|struct mach_msg_overwrite_args\|struct vm_allocate_args\|struct vm_deallocate_args\|struct vm_protect_args' "$H" | head -100
fi

echo
echo "== 4. 若 3 为空：直接从 trap 实现反推字段名 =="
grep -rn -A30 'mach_msg_overwrite_trap(' "$X/osfmk/ipc/mach_msg.c" | sed -n '1,45p'

echo
echo "== 5. vm_allocate trap 实现 =="
grep -rn -A25 '_kernelrpc_mach_vm_allocate_trap(' "$X/osfmk/mach/vm_mach.c" | sed -n '1,40p'
echo "== done $(date -u +%FT%TZ)"
