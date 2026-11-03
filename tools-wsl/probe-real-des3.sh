#!/bin/bash
set -u
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
K=$T/../build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/mach.development.bcm2837.unstripped
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/mach.development.bcm2837.unstripped
NM=/usr/lib/llvm-18/bin/llvm-nm
OD=/usr/lib/llvm-18/bin/llvm-objdump
O=/mnt/e/Code/HackIos/out/real-des3.txt
{
echo "== ccdes.h 全部 extern/声明 =="
grep -n 'extern\|mode(void)\|parity\|weak' "$T/EXTERNAL_HEADERS/corecrypto/ccdes.h" | head -40
echo "== ccn.h / cc14 前缀宏在哪 =="
grep -rln 'cc14_ccdes3_cbc_encrypt_mode\|define cc14_' "$T/EXTERNAL_HEADERS" "$T/tools" 2>/dev/null | head -5
grep -rn 'cc14_' "$T/EXTERNAL_HEADERS/corecrypto/ccdes.h" 2>/dev/null | head -5
echo "== 反汇编 cc14_ccdes3_cbc_* / cc14_ccdes_key_set_odd_parity / cc14_ccpad_cts3_* =="
for a in 0xfffffff0079e6954 0xfffffff0079e698c 0xfffffff0079e74cc 0xfffffff0079ead5c 0xfffffff0079fcb94; do
  echo "--- 0x$a"
  $OD -d --start-address=$a --stop-address=$(printf '0x%x' $((a + 16))) "$K" 2>/dev/null | grep -E '^[0-9a-f]+:'
done
echo "== 这些地址属于哪个数据符号 =="
$NM "$K" 2>/dev/null | grep -E '^fffffff00721[0-9a-f]{4} ' | sort > /tmp/dc.txt
for off in c80 bb8 c78 f78 f48 b30 d88 dd0; do
  addr="fffffff00721${off}"
  printf "%s -> " "$addr"; grep -i "^$addr " /tmp/dc.txt | head -3 | tr '\n' ' '; echo ""
done
echo "== ccdes3_ltc_cbc / ccdes_ltc_cbc 数据符号是否存在 =="
$NM "$K" 2>/dev/null | grep -i 'des3.*cbc\|des.*cbc' | head -20
echo "== register_crypto.h 里这几个字段的类型 =="
grep -n 'ccdes3_cbc_encrypt\|ccdes3_cbc_decrypt\|ccdes_key_set_odd_parity\|ccpad_cts3\|ccaes_cbc' "$T/libkern/libkern/crypto/register_crypto.h"
echo "== bsd/nfs/gss/ccrypto.c 头部 =="
head -40 "$T/bsd/nfs/gss/ccrypto.c"
} > "$O" 2>&1
echo done
