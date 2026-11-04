#!/bin/bash
set -u
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
B=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837
O=/mnt/e/Code/HackIos/out/probes/cc-syms-check.txt
NM=$(command -v llvm-nm || command -v nm)
{
  echo "== nm tool: $NM =="
  echo "== candidate kernel binaries =="
  find /home/unixnu/code/umi-work-pin/out/umi-xnu -maxdepth 6 -name 'kernel.macho' -o -maxdepth 6 -name 'kernelcache*' 2>/dev/null | head
  ls -l "$B" 2>/dev/null | head -30
  K=$(find /home/unixnu/code/umi-work-pin/out -name 'kernel.macho' 2>/dev/null | head -1)
  echo "== using kernel: $K =="
  if [ -n "$K" ]; then
    echo "== corecrypto symbols present? =="
    "$NM" -gU "$K" 2>/dev/null | grep -E '_cc(md5|sha1|sha256|sha384|sha512)_di$'
    echo "--- digest/hmac entry points ---"
    "$NM" -gU "$K" 2>/dev/null | grep -E '_ccdigest_(init|update|final)$|_ccdigest$|_cchmac_(init|update|final)$|_cchmac$|_register_crypto_functions$|_g_crypto_funcs$'
    echo "== init_entry_set symbols =="
    "$NM" "$K" 2>/dev/null | grep -iE 'init_entry_set' | head -20
    echo "== a sample EARLY_BOOT registrant (kmem_crypto_init / kalloc_boot_init) =="
    "$NM" "$K" 2>/dev/null | grep -iE 'kmem_crypto_init|kalloc_boot_init' | head
  fi
  echo "== startup.h: stage enum + macros =="
  grep -n 'EARLY_BOOT' "$W/osfmk/kern/startup.h" | head -20
  sed -n '735,790p' "$W/osfmk/kern/startup.h" | cat -n
  echo "== vm_kern.c STARTUP precedent =="
  grep -n -B4 'STARTUP(EARLY_BOOT' "$W/osfmk/kern/vm_kern.c" "$W/osfmk/vm/vm_kern.c" 2>/dev/null | head -30
  echo "== does any libkern file already use STARTUP? =="
  grep -rn 'STARTUP(' "$W/libkern" 2>/dev/null | head -20
} > "$O" 2>&1
echo done
