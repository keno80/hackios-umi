#!/bin/bash
set -u
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/cc-kit-fields2.txt
{
  echo "== struct crypto_functions =="
  grep -n -A100 'crypto_functions {' "$W/libkern/libkern/crypto/register_crypto.h" | head -130
  echo "== crypto_random / rand wrappers =="
  cat -n "$W/libkern/crypto/corecrypto_rand.c"
} > "$O" 2>&1
echo done
