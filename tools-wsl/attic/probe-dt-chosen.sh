#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/probes/dt-chosen.txt
{
  echo "== dtb files under work pin =="
  find "$WS" -name '*.dtb' -newermt '2026-10-01' 2>/dev/null | head -10
  echo "== g_crypto_funcs assignment =="
  grep -rn "g_crypto_funcs *=" "$X" --include=*.c --include=*.cpp 2>/dev/null | head -10
  echo "== who registers crypto funcs (crypto_add / kit) =="
  grep -rn "crypto_funcs\b" "$X" --include=*.c --include=*.cpp --include=*.h 2>/dev/null | grep -v corecrypto_sha2 | head -20
  echo "== security_init =="
  grep -rn "security_init" "$X/bsd/kern/kern_security.c" 2>/dev/null | head -5
} > "$O" 2>&1
echo done
