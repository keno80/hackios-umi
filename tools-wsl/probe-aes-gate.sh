#!/bin/bash
# 取证：aes.c 需要哪些 kit 字段、register_crypto.h 里 AES 组的偏移与类型
set -u
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/mach.development.bcm2837.unstripped
OD=$(command -v llvm-objdump || command -v objdump)
OUT=/mnt/e/Code/HackIos/out/aes-gate.txt
{
  echo "== aes_encrypt_key128 全函数"
  $OD -d --start-address=0xfffffff0078dd9fc --stop-address=0xfffffff0078dda58 "$K" 2>&1
  echo "== libkern/crypto/aes.c"
  cat "$W/libkern/crypto/aes.c" 2>&1
  echo "== register_crypto.h: crypto_functions 里 ccaes/ccdes/ccgcm 字段"
  grep -n 'ccaes\|ccdes\|cctdes\|ccgcm\|ccpad\|ccchacha\|ccrsa\|ccpkcs1\|ccpbkdf2\|des_key_schedule\|struct crypto_functions\|} crypto_functions' "$W/libkern/include/libkern/crypto/register_crypto.h" 2>&1
  echo "== corecrypto ccaes.h 可用符号"
  grep -n 'ccaes_encrypt_init\|ccaes_decrypt_init\|ccaes_cbc_encrypt\|ccaes_cbc_decrypt\|ccaes_ecb_encrypt\|ccaes_ecb_decrypt\|ccaes_ctr_encrypt\|cccbc_init\|cccbc_done\|ccgcm' "$W/EXTERNAL_HEADERS/corecrypto/ccaes.h" 2>&1 | head -40
  echo "== aes.c 依赖的头是否存在"
  ls "$W/EXTERNAL_HEADERS/corecrypto/" | tr '\n' ' '
  echo
  echo "== 产物里 ccaes_* 符号"
  NM=$(command -v llvm-nm || command -v nm)
  $NM --defined-only "$K" 2>/dev/null | grep -E '_(cccbc_init|ccaes_[a-z_0-9]+|ccgcm_[a-z_0-9]+|ccaes_ni_[a-z_0-9]+)$' | head -40
} > "$OUT" 2>&1
echo done
