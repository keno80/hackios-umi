#!/bin/bash
# 取证：libkern/crypto 下有哪些 provider 文件、是否已有完整 crypto_functions 实例、构建清单收了谁
set -u
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
OUT=/mnt/e/Code/HackIos/out/provider.txt
{
  echo "== libkern/crypto 目录"
  ls -l "$W/libkern/crypto/"
  echo "== 谁定义 crypto_functions 实例（结构体初始化）"
  grep -rn --include='*.c' --include='*.h' -E 'crypto_functions_t|= *\{|\}\s*crypto_functions|struct crypto_functions +[a-z]' "$W/libkern/crypto/" | head -30
  echo "== register_crypto_functions 调用者（全树）"
  grep -rn --include='*.c' --include='*.cpp' 'register_crypto_functions *(' "$W" | grep -v 'int$' | head -20
  echo "== corecrypto_aes.c 前 60 行"
  sed -n '1,60p' "$W/libkern/crypto/corecrypto_aes.c"
  echo "== libkern 构建清单里收了哪些 crypto 源"
  grep -rn 'crypto' "$W/libkern/Make" "$W/libkern/Makefile" 2>/dev/null | head -30
  ls "$W/libkern/" | head -30
  echo "== 组件文件（*.components / SETUP.*）"
  find "$W/libkern" -maxdepth 1 -name 'SETUP*' -o -maxdepth 1 -name '*.components' -o -maxdepth 1 -name 'Make*' | head
} > "$OUT" 2>&1
echo done
