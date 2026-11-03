#!/bin/bash
# 分类：kit 里用到的每个 corecrypto 访问器，是「回读 g_crypto_funcs 的桩」还是「真实现」
set -u
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/mach.development.bcm2837.unstripped
NM=/usr/lib/llvm-18/bin/llvm-nm
OD=/usr/lib/llvm-18/bin/llvm-objdump
O=/mnt/e/Code/HackIos/out/accessor-class.txt
mkdir -p "$(dirname "$O")"

SYMS="ccdigest_init ccdigest_update ccdigest_final ccdigest ccmd5_di ccsha1_di ccsha256_di ccsha384_di ccsha512_di \
cchmac_init cchmac_update cchmac_final cchmac \
ccaes_ecb_encrypt_mode ccaes_ecb_decrypt_mode ccaes_cbc_encrypt_mode ccaes_cbc_decrypt_mode ccaes_ctr_crypt_mode \
ccaes_xts_encrypt_mode ccaes_xts_decrypt_mode ccaes_gcm_encrypt_mode ccaes_gcm_decrypt_mode \
ccgcm_init_with_iv ccgcm_inc_iv ccchacha20poly1305_info \
ccdes_ecb_encrypt_mode ccdes_ecb_decrypt_mode cctdes_ecb_encrypt_mode cctdes_encrypt24 cctdes_decrypt24 \
ccdes3_cbc_encrypt_mode ccdes3_cbc_decrypt_mode ccdes_key_is_weak ccdes_key_set_odd_parity \
ccpad_cts3_encrypt ccpad_cts3_decrypt ccrng \
ccrsa_make_pub ccrsa_verify_pkcs1v15 \
ccaes_gladman_cbc_encrypt_mode ccaes_gladman_cbc_decrypt_mode ccaes_ltc_ecb_encrypt_mode ccaes_ltc_cbc_encrypt_mode \
cc14_ccaes_cbc_encrypt_mode cc14_ccaes_cbc_decrypt_mode cc14_ccaes_ecb_encrypt_mode \
ccaes_v7m_cbc_encrypt_mode ccaes_v7m_cbc_decrypt_mode ccaes_v8_cbc_encrypt_mode ccaes_v8_cbc_decrypt_mode \
ccaes_neon_cbc_encrypt_mode ccaes_armv8_cbc_encrypt_mode"

# 全量符号表（地址 名字），用于精确命中
$NM "$K" 2>/dev/null | grep -E '^[0-9a-f]+ [TtSsDd] _' > /tmp/allsyms.txt

{
echo "== 全树 aes/des/cts 相关符号（定序）=="
grep -E '_(cc|cc14_)?[a-z0-9_]*(aes|des|cts|gladman|ltc)[a-z0-9_]*$' /tmp/allsyms.txt | sort -k3
echo ""
echo "== 每个候选符号：地址 + 前 8 条指令 + 桩判定 =="
for s in $SYMS; do
  line=$(grep -E "^[0-9a-f]+ [TtSsDd] _${s}$" /tmp/allsyms.txt | head -1)
  if [ -z "$line" ]; then
    echo "--- $s : NOT FOUND"
    continue
  fi
  addr=$(echo "$line" | cut -d' ' -f1)
  kind=$(echo "$line" | cut -d' ' -f2)
  printf -- "--- %s [%s] @ 0x%s\n" "$s" "$kind" "$addr"
  $OD -d --start-address="0x$addr" --stop-address="$(printf '0x%x' $((0x$addr + 32)))" \
      --no-show-raw-insn "$K" 2>/dev/null \
    | grep -E '^[0-9a-f]+:' | head -8
done
} > "$O" 2>&1
echo "written $O"
