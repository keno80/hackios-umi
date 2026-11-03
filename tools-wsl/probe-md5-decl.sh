#!/bin/bash
# 取证：ccmd5_di / ccmd4_ltc_di 在哪声明；corecrypto_md5.c 怎么用
set -u
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
OUT=/mnt/e/Code/HackIos/out/md5-decl.txt
{
  echo "== grep ccmd5_di"
  grep -rn 'ccmd5_di' "$W/libkern" "$W/bsd/libkern" 2>/dev/null | head -10
  echo "== grep ccmd4_ltc_di"
  grep -rn 'ccmd4_ltc_di' "$W/libkern" 2>/dev/null | head -10
  echo "== corecrypto_md5.c"
  sed -n '28,70p' "$W/libkern/crypto/corecrypto_md5.c"
  echo "== crypto_internal.h"
  cat "$W/libkern/libkern/crypto/crypto_internal.h" 2>/dev/null | sed -n '1,60p'
} > "$OUT" 2>&1
echo done
