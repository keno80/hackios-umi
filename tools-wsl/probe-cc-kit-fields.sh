#!/bin/bash
set -u
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
K=/home/unixnu/code/umi-work-pin/out/umi/xnu/stage2/EFI/UniXNU/Payloads/kernel.macho
O=/mnt/e/Code/HackIos/out/cc-kit-fields.txt
{
  echo "== struct crypto_functions full text =="
  awk '/^struct crypto_functions/,/^};/' "$W/libkern/libkern/crypto/register_crypto.h" | cat -n
  echo "== candidate symbols in kernel =="
  for s in ccrng_get ccntr_init ccgcm_init_with_iv ccpbkdf2_hmac ccrsa_make_pub ccrsa_mksign_priv \
           ccdes_key_is_weak_fn ccdes_set_odd_parity ccchacha20poly1305_cccrypto_info \
           ccaes_ecb_encrypt ccaes_cbc_encrypt ccaes_ctr32_encrypt_blocks ccaes_xts_encrypt \
           ccsha224_di ccaes_gcm ccmode_cbc_factory; do
    printf '%-32s ' "$s"; llvm-nm "$K" 2>/dev/null | grep -c "_$s"
  done
  echo "== ecb/cbc/gcm mode structs =="
  llvm-nm "$K" 2>/dev/null | grep -E '_ccaes_(ecb|cbc|ctr|gcm|xts)|_ccdes_ecb|_cctdes_ecb|_ccntr' | head -30
  echo "== rbg / rng =="
  llvm-nm "$K" 2>/dev/null | grep -E '_ccrng|_ccdrbg|_cckprng' | head -20
  echo "== hmac =="
  llvm-nm "$K" 2>/dev/null | grep -E '_cchmac' | head -20
} > "$O" 2>&1
echo done
