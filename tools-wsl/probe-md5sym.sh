#!/bin/bash
# 取证：ccmd5_di 是函数还是数据
set -u
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/mach.development.bcm2837.unstripped
OUT=/mnt/e/Code/HackIos/out/md5sym.txt
{
  echo "== disasm 0x...79f0180"
  llvm-objdump -d --start-address=0xfffffff0079f0180 --stop-address=0xfffffff0079f01a0 "$K" 2>&1
  echo "== nm md5"
  llvm-nm --defined-only "$K" 2>/dev/null | grep -E 'ccmd4_ltc_di|_ccmd5_di'
} > "$OUT" 2>&1
echo done
