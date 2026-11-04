#!/bin/bash
# 取证：kit 每个字段的类型/消费者/本树可用实现
set -u
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
H=$W/libkern/libkern/crypto/register_crypto.h
OUT=/mnt/e/Code/HackIos/out/probes/kit-fields.txt
{
  echo "== register_crypto.h 1..200（typedef 与 include）"
  sed -n '1,200p' "$H"
  echo "== 谁消费这些字段（在 .c 里）"
  for f in ccmd5_di ccaes_ecb_encrypt ccaes_cbc_encrypt ccaes_cbc_decrypt ccaes_ctr_crypt ccaes_xts_encrypt ccaes_gcm_encrypt ccgcm_init_with_iv_fn ccgcm_inc_iv_fn ccchacha20poly1305_fns ccdes_ecb_encrypt cctdes_cbc_encrypt ccdes_key_is_weak_fn ccdes_key_set_odd_parity_fn ccpad_cts3_encrypt_fn ccrsa_make_pub_fn ccrsa_verify_pkcs1v15_fn digest_ctx_size_fn hmac_ctx_size_fn hmac_generate_fn; do
    printf -- '-- %s\n' "$f"
    grep -rl --include='*.c' --include='*.cpp' --include='*.m' "\b$f\b" "$W" 2>/dev/null | head -4
  done
  echo "== 本树可用的实现声明"
  for h in ccmd4.h ccaes.h ccdes.h ccpad.h ccmode.h ccchacha20poly1305.h ccrsa.h; do
    printf -- '-- %s\n' "$h"
    grep -nE '^[a-z_].*\(|_mode\(void\)|_di\(void\)|ccgcm_init_with_iv|ccgcm_inc_iv|ccpad_cts3|ccdes_key_is_weak|ccdes_key_set_odd_parity|ccrsa_make_pub|ccrsa_verify_pkcs1v15' "$W/EXTERNAL_HEADERS/corecrypto/$h" 2>/dev/null | head -30
  done
} > "$OUT" 2>&1
echo done
