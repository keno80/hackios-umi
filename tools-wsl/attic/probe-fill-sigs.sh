#!/bin/bash
# 取证：ccmd5_di 声明、ccrsa_verify_pkcs1v15 完整签名、ccchacha20poly1305_info 声明
set -u
E=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work/EXTERNAL_HEADERS/corecrypto
OUT=/mnt/e/Code/HackIos/out/probes/fill-sigs.txt
{
  echo "== ccmd4.h"
  grep -n 'ccmd5_di\|ccdigest_info' "$E/ccmd4.h"
  echo "== ccrsa_verify_pkcs1v15"
  sed -n '515,525p' "$E/ccrsa.h"
  echo "== ccrsa_make_pub"
  sed -n '222,230p' "$E/ccrsa.h"
  echo "== ccchacha20poly1305_info/init"
  sed -n '112,135p' "$E/ccchacha20poly1305.h"
} > "$OUT" 2>&1
echo done
