#!/bin/bash
set -u
K=/home/unixnu/code/umi-work-pin/out/umi/xnu/stage2/EFI/UniXNU/Payloads/kernel.macho
O=/mnt/e/Code/HackIos/out/probes/verify-kit.txt
{
  echo "== kernel.macho =="
  ls -l "$K"; sha256sum "$K" | cut -c1-64
  echo "== symbols =="
  llvm-nm "$K" 2>/dev/null | grep -E 'umi_crypto_kit|_g_crypto_funcs|_register_crypto_functions|_ccrng$' | head -10
  echo "== PE_init_iokit disassembly around our call =="
  llvm-objdump -d --disassemble-symbols=_PE_init_iokit "$K" 2>/dev/null | grep -nE 'bl.*(umi_crypto_kit_register|ConfigureIOKit|InitIOKit)' | head -10
  echo "== register_crypto_functions body (guards?) =="
  llvm-objdump -d --disassemble-symbols=_register_crypto_functions "$K" 2>/dev/null | head -25
  echo "== umi_crypto_kit_register: does it call ccrng/ccsha1_di? =="
  llvm-objdump -d --disassemble-symbols=_umi_crypto_kit_register "$K" 2>/dev/null | grep -E 'bl\s' | head -20
} > "$O" 2>&1
echo done
