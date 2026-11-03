#!/bin/bash
set -u
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
D=/home/unixnu/code/umi-work-pin/devices/umi
K=/home/unixnu/code/umi-work-pin/out/umi/xnu/stage2/EFI/UniXNU/Payloads/kernel.macho
O=/mnt/e/Code/HackIos/out/upstream-crypto-plan.txt
{
  echo "== rng symbols (in-tree + cc14) =="
  llvm-nm "$K" 2>/dev/null | grep -iE '_cc(rng|nr)' | head -20
  echo "== upstream umi tooling mentions register_crypto / crypto_functions / provider =="
  grep -rn 'register_crypto\|crypto_functions\|provider_registered\|g_crypto_funcs' "$D" 2>/dev/null | head -30
  echo "== scripts referencing crypto selftests =="
  grep -rln 'crypto_selftests' "$D" /home/unixnu/code/umi-work-pin/scripts 2>/dev/null | head
  echo "== build-corecrypto-14.py: how it reports provider_registered =="
  grep -n -B3 -A8 'provider_registered' "$D/scripts/build-corecrypto-14.py" 2>/dev/null | head -40
  echo "== any umi patch already touching vm_kern/kmem_crypto =="
  grep -ln 'kmem_crypto' "$D/patches/umi-xnu/"*.patch 2>/dev/null
  echo "== zalloc_percpu_permanent signature =="
  grep -rn 'zalloc_percpu_permanent' "$W/osfmk/kern/zalloc.h" | head -5
} > "$O" 2>&1
echo done
