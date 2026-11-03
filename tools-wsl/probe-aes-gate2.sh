#!/bin/bash
# 取证：定位 aes.c / register_crypto.h，列出 AES 组字段与 aes.c 用到的字段
set -u
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
OUT=/mnt/e/Code/HackIos/out/aes-gate2.txt
{
  echo "== find"
  find "$W/libkern" -name 'aes.c' -o -name 'register_crypto.h' -o -name 'aes.h' 2>/dev/null
  echo "== register_crypto.h: struct crypto_functions 全文（带行号）"
  H=$(find "$W" -name register_crypto.h | head -1)
  echo "H=$H"
  grep -n -A110 'struct crypto_functions' "$H" | sed -n '1,140p'
  echo "== aes.c 全文"
  A=$(find "$W/libkern" -name aes.c | head -1)
  echo "A=$A"
  cat -n "$A" 2>&1 | sed -n '30,200p'
} > "$OUT" 2>&1
echo done
