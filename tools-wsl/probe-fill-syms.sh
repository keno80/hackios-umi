#!/bin/bash
# 取证：计划填入的每个实现——头文件声明 + 产物内核里的符号是否存在
set -u
W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
E=$W/EXTERNAL_HEADERS/corecrypto
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/mach.development.bcm2837.unstripped
NM=$(command -v llvm-nm || command -v nm)
OUT=/mnt/e/Code/HackIos/out/fill-syms.txt
{
  echo "== 声明"
  for f in ccmd5_di ccaes_ecb_encrypt_mode ccaes_ecb_decrypt_mode ccaes_cbc_encrypt_mode ccaes_cbc_decrypt_mode \
           ccaes_ctr_crypt_mode ccaes_xts_encrypt_mode ccaes_xts_decrypt_mode ccaes_gcm_encrypt_mode ccaes_gcm_decrypt_mode \
           ccgcm_init_with_iv ccgcm_inc_iv ccdes_ecb_encrypt_mode ccdes_ecb_decrypt_mode ccdes_cbc_encrypt_mode ccdes_cbc_decrypt_mode \
           ccdes3_ecb_encrypt_mode ccdes3_ecb_decrypt_mode ccdes3_cbc_encrypt_mode ccdes3_cbc_decrypt_mode \
           ccdes_key_is_weak ccdes_key_set_odd_parity ccpad_cts3_encrypt ccpad_cts3_decrypt \
           ccrsa_make_pub ccrsa_verify_pkcs1v15 \
           ccchacha20poly1305_info ccchacha20poly1305_init ccchacha20poly1305_reset ccchacha20poly1305_setnonce \
           ccchacha20poly1305_incnonce ccchacha20poly1305_aad ccchacha20poly1305_encrypt ccchacha20poly1305_finalize \
           ccchacha20poly1305_decrypt ccchacha20poly1305_verify; do
    hit=$(grep -rn -B2 "^[^/*]*\b$f *(" "$E" 2>/dev/null | grep -E "\b$f *\(" | head -2)
    printf -- '-- %s\n%s\n' "$f" "$hit"
  done
  echo "== 内核符号"
  $NM --defined-only "$K" 2>/dev/null | grep -E '_(ccmd5_di|ccaes_(ecb|cbc|ctr|xts|gcm)[a-z_0-9]*mode|ccgcm_(init_with_iv|inc_iv)|ccdes[0-9]?_(ecb|cbc)[a-z_]*mode|ccdes_key_(is_weak|set_odd_parity)|ccpad_cts3_(encrypt|decrypt)|ccrsa_(make_pub|verify_pkcs1v15)|ccchacha20poly1305_(info|init|reset|setnonce|incnonce|aad|encrypt|finalize|decrypt|verify))$' | sort -k3
  echo "== ccmode_gcm 结构首字段（size 检查用）"
  grep -n -A12 'struct ccmode_gcm {' "$E/ccmode.h" | head -20
  echo "== ccmode_cbc 结构首字段"
  grep -n -A10 'struct ccmode_cbc {' "$E/ccmode.h" | head -16
} > "$OUT" 2>&1
echo done
