#!/bin/bash
set -u
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/probes/cc-headers.txt
{
  echo "== ls libkern/crypto =="
  ls -l "$W/libkern/crypto"
  echo "== register_crypto.c head 70 =="
  sed -n '1,70p' "$W/libkern/crypto/register_crypto.c" | cat -n
  echo "== where are corecrypto headers =="
  find "$W" -name 'ccmd5.h' 2>/dev/null | head -10
  find "$W" -type d -name corecrypto 2>/dev/null | head -10
  echo "== who includes corecrypto/ccmd5.h =="
  grep -rl 'corecrypto/ccmd5.h' "$W/libkern" "$W/bsd" "$W/osfmk" 2>/dev/null | head -20
  echo "== does any libkern file build with corecrypto includes =="
  grep -rn 'ccdigest.h' "$W/libkern" 2>/dev/null | head -20
  echo "== register_crypto_functions callers =="
  grep -rn 'register_crypto_functions' "$W" --include=*.c --include=*.m --include=*.cpp --include=*.h 2>/dev/null | head -20
  echo "== libkern Makefile crypto lines =="
  grep -n 'crypto' "$W/libkern/Make" 2>/dev/null | head -40
  ls "$W/libkern"
  echo "== CONFIG_CORECRYPTO in config files =="
  grep -rn 'CORECRYPTO' "$W/bsd/conf" "$W/osfmk/conf" "$W/libkern/conf" 2>/dev/null | head -30
} > "$O" 2>&1
echo done
