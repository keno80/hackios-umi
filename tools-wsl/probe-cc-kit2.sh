#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
K=$WS/out/umi-xnu/umi/kernel/source-kernel.macho
O=/mnt/e/Code/HackIos/out/probes/cc-kit2.txt
{
  echo "== struct crypto_functions (crypto.h) =="
  sed -n '/^typedef struct crypto_functions/,/crypto_functions;/p' "$X/libkern/libkern/crypto/crypto.h"
  echo "== corecrypto accessors linked in kernel =="
  llvm-nm --defined-only "$K" 2>/dev/null | grep -E "_(ccsha1_di|ccsha2_256_di|ccsha2_384_di|ccsha2_512_di|ccmd5_di|ccdigest_init|ccdigest_update|ccdigest_final|cchmac_init|cchmac_update|cchmac_final|ccaes_encrypt_init|ccn_init)$" | head -20
  echo "== any unixnu patch mentioning crypto =="
  grep -rln "register_crypto\|g_crypto_funcs" "$WS/devices" 2>/dev/null | head -10
  echo "== unixnu docs about crypto =="
  grep -rn "crypto" "$WS/devices/umi" 2>/dev/null | grep -iv "sha2-384" | head -15
} > "$O" 2>&1
echo done
