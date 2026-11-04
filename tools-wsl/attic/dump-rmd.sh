#!/bin/bash
S=/home/unixnu/code/umi-work-pin/devices/umi/overlay/Platforms/Xiaomi/umiPkg/Application/UmiMemoryDiag
O=/mnt/e/Code/HackIos/out/rmd-src
mkdir -p "$O"
for f in UmiMemoryDiag.c RamProbe.c SmemRead.h RamGuard.h; do
  [ -f "$S/$f" ] && cp "$S/$f" "$O/$f" && echo "  copied $f ($(wc -l < "$O/$f") 行)"
done
echo "== 目录里还有什么"
ls -1 "$S" | sed 's#^#  #'
echo "== 谁调用 ProbeCandidateRam / 主入口尾部"
grep -n -E "UefiMain|ProbeCandidateRam|return |ReadKeyStroke|while" "$S/UmiMemoryDiag.c" | tail -25
