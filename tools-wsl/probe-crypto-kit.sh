#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
F=$WS/out/umi-xnu/feeds/xnu-0b4b910d
O=/mnt/e/Code/HackIos/out/probes/crypto-kit.txt
{
  echo "== upstream callers in feeds =="
  grep -rn "register_crypto_functions" "$F" --include=*.c --include=*.cpp 2>/dev/null | grep -v "register_crypto.c" | head -10
  echo "== struct crypto_functions =="
  sed -n '1,80p' "$X/libkern/libkern/crypto/register_crypto.h" | grep -n "" | sed -n '20,80p'
  echo "== libkern/crypto files =="
  ls "$X/libkern/crypto"
  echo "== corecrypto in build tree? =="
  ls "$X/osfmk/corecrypto" 2>/dev/null | head -8
  echo "== ccsha1 symbol present in kernel? =="
  llvm-nm --defined-only "$WS/out/umi-xnu/umi/kernel/source-kernel.macho" 2>/dev/null | grep -w "ccsha1\|_ccsha1\|ccdigest_init\|_register_crypto_functions" | head -10
} > "$O" 2>&1
echo done
