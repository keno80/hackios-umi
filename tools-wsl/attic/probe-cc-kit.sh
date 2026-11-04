#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
F=$WS/out/umi-xnu/feeds/xnu-0b4b910d
K=$WS/out/umi-xnu/umi/kernel/source-kernel.macho
O=/mnt/e/Code/HackIos/out/probes/cc-kit.txt
{
  echo "== designated-init kit anywhere in tree/feeds =="
  grep -rn "ccsha1_di" "$X" "$F" 2>/dev/null | grep -v "corecrypto_sha1.c\|register_crypto.h" | head -10
  echo "== struct crypto_functions instances declared =="
  grep -rn "crypto_functions .*= {" "$X" "$F" 2>/dev/null | head -10
  echo "== corecrypto symbols actually linked into kernel =="
  llvm-nm --defined-only "$K" 2>/dev/null | grep -w "ccsha1\|ccsha2_256\|ccsha2_384\|ccsha2_512\|ccdigest_init\|ccdigest_update\|ccdigest_final\|ccn_ccrypt" | head -12
  echo "== count of cc* symbols =="
  llvm-nm --defined-only "$K" 2>/dev/null | grep -c " S _cc\| s _cc"
  echo "== who calls SHA1Init in iokit =="
  grep -rn "SHA1Init\|SHA1Update" "$X/iokit" 2>/dev/null | head -10
} > "$O" 2>&1
echo done
