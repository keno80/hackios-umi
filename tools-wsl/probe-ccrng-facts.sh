#!/bin/bash
set -u
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/ccrng-facts.txt
{
  echo "== source defining ccrng_prng =="
  grep -rln 'ccrng_prng' "$W" --include=*.c --include=*.h --include=*.cpp 2>/dev/null | head
  echo "== declarations in ccrng.h =="
  cat -n "$W/EXTERNAL_HEADERS/corecrypto/ccrng.h"
  echo "== ccrng_crypto.h =="
  grep -n 'ccrng' "$W/EXTERNAL_HEADERS/corecrypto/ccrng_crypto.h" | head -20
  echo "== who uses ks_rng_ctx =="
  grep -rn 'ks_rng_ctx' "$W/osfmk/vm" | head -20
  echo "== who calls crypto_random_generate / uniform =="
  grep -rn 'crypto_random_generate\|crypto_random_uniform' "$W" --include=*.c 2>/dev/null | grep -v libkern/crypto | head -20
} > "$O" 2>&1
echo done
