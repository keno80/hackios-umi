#!/bin/bash
# 取证：run-11-kit2 的新 pc 落在哪个函数、那条 ldr 取的是哪个字段
set -u
K=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/mach.development.bcm2837.unstripped
OUT=/mnt/e/Code/HackIos/out/abort11.txt
{
  echo "== pc 0xfffffff0078ddaf4 所属函数与前后指令"
  llvm-objdump -d --start-address=0xfffffff0078ddac0 --stop-address=0xfffffff0078ddb30 "$K" 2>&1 | tail -30
  echo "== 附近符号"
  llvm-nm -n --defined-only "$K" | awk '$1>="fffffff0078dda00" && $1<="fffffff0078ddc20"'
  echo "== tcp_init 调用点上下文"
  llvm-objdump -d --start-address=0xfffffff00763b6f0 --stop-address=0xfffffff00763b720 "$K" 2>&1 | tail -14
} > "$OUT" 2>&1
echo done
