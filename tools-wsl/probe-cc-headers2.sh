#!/bin/bash
set -u
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/cc-headers2.txt
{
  echo "== EXTERNAL_HEADERS/corecrypto =="
  ls "$W/EXTERNAL_HEADERS/corecrypto"
  echo "== osfmk/corecrypto headers (subset) =="
  ls "$W/osfmk/corecrypto" | head -60
  echo "== libkern/crypto/corecrypto_sha1.c =="
  cat -n "$W/libkern/crypto/corecrypto_sha1.c"
  echo "== libkern/crypto/corecrypto_md5.c =="
  cat -n "$W/libkern/crypto/corecrypto_md5.c"
  echo "== register_crypto.h struct =="
  sed -n '28,120p' "$W/libkern/libkern/crypto/register_crypto.h" | cat -n
  echo "== who includes ccsha1.h (kernel trees) =="
  grep -rl 'corecrypto/ccsha1.h' "$W/libkern" "$W/bsd" "$W/osfmk" "$W/iokit" 2>/dev/null | head -20
  echo "== libkern Makefile crypto =="
  grep -n 'crypto' "$W/libkern/Makefile" | head -40
  echo "== g_crypto_funcs users =="
  grep -rn 'g_crypto_funcs' "$W/libkern" "$W/bsd" "$W/osfmk" 2>/dev/null | head -40
} > "$O" 2>&1
echo done
