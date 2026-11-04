#!/bin/bash
set -u
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/probes/boot-order.txt
{
  echo "== other definitions of crypto_random_kmem_ctx_size =="
  grep -rn 'crypto_random_kmem_ctx_size' "$W" --include=*.c --include=*.h 2>/dev/null | head -20
  echo "== startup_module_init call sites =="
  grep -rn 'startup_module_init' "$W/osfmk" "$W/bsd" "$W/iokit" 2>/dev/null | grep -v 'startup\.\(h\|c\):' | head -30
  echo "== bootstrap.c sequence =="
  grep -n 'startup_module_init\|IOKernelInit\|kmemory\|machine_init\|proc_kernel_thread\|bsd_init\|vm_slab' "$W/bsd/kern/bootstrap.c" | head -40
  echo "== who calls IOKernelInit / IOStartIOKit =="
  grep -rn 'IOKernelInit' "$W" --include=*.c --include=*.cpp --include=*.h 2>/dev/null | head -20
  echo "== IOStartIOKit.cpp context 140-200 =="
  sed -n '140,200p' "$W/iokit/Kernel/IOStartIOKit.cpp" | cat -n
} > "$O" 2>&1
echo done
