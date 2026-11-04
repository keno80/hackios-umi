#!/bin/bash
# 在源码树里找「真实现」的声明位置，确认能否直接 extern 调用
set -u
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
O=/mnt/e/Code/HackIos/out/probes/real-decl.txt
{
for s in cc14_ccaes_cbc_encrypt_mode cc14_ccaes_cbc_decrypt_mode \
         cc14_ccdes3_cbc_encrypt_mode cc14_ccdes3_cbc_decrypt_mode \
         cc14_ccdes_key_set_odd_parity cc14_ccpad_cts3_encrypt cc14_ccpad_cts3_decrypt \
         ccsha1_ltc_di ccsha1_di ccaes_cbc_encrypt_mode ccaes_cbc_decrypt_mode \
         ccdes3_cbc_encrypt_mode ccpad_cts3_encrypt ccdes_key_set_odd_parity; do
  echo "=== $s ==="
  grep -rn --include='*.h' --include='*.c' --include='*.cpp' "\b$s\b" "$T/EXTERNAL_HEADERS" "$T/libkern" "$T/bsd" "$T/pexpert" 2>/dev/null | head -8
done
echo "=== ccaes.h 全文里的 mode 声明 ==="
find "$T/EXTERNAL_HEADERS" -name 'ccaes.h' -exec grep -n 'mode\|cc14' {} \; 2>/dev/null | head -30
echo "=== ccpad.h ==="
find "$T/EXTERNAL_HEADERS" -name 'ccpad.h' -exec grep -n 'cts3\|cc14' {} \; 2>/dev/null | head -20
echo "=== ccsha1 头 ==="
find "$T/EXTERNAL_HEADERS" -name 'ccsha1*.h' | head; find "$T/EXTERNAL_HEADERS" -name 'ccsha1_internals.h' -exec cat {} \; 2>/dev/null | head -40
} > "$O" 2>&1
echo done
