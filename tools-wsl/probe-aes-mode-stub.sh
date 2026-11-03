#!/bin/bash
# 取证：ccaes_*_mode 访问器本体到底返回什么（是否为桩）
set -u
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/mach.development.bcm2837.unstripped
OUT=/mnt/e/Code/HackIos/out/aes-mode-stub.txt
{
  echo "== 0x745cf6c..0x745d070 这一片（含 ccaes/ccdes/ccpad 访问器）"
  llvm-objdump -d --start-address=0xfffffff00745cf60 --stop-address=0xfffffff00745d070 "$K" 2>&1 | sed -n '1,80p'
  echo "== 真正的 ccaes_ecb_encrypt_mode（0x79df6c4）"
  llvm-objdump -d --start-address=0xfffffff0079df6b8 --stop-address=0xfffffff0079df6d8 "$K" 2>&1 | tail -12
  echo "== 这些地址分别属于哪个符号"
  llvm-nm -n --defined-only "$K" | awk '$1>="fffffff00745cf00" && $1<="fffffff00745d080"'
  echo "== 谁在 0x745c 段：找该地址区间所属 .o（看相邻符号名）"
  llvm-nm -n --defined-only "$K" | awk '$1>="fffffff00745cc00" && $1<="fffffff00745d200"{print}' | head -30
} > "$OUT" 2>&1
echo done
