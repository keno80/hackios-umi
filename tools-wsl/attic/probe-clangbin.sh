#!/bin/bash
# 查 CLANG_BIN 是从哪 injected 的（conf/tools_def 还是 AutoGen）
{
echo "== conf 目录"
ls -l /home/unixnu/code/umi-work-pin/out/unixnu/umi/edk2-conf/
echo "== tools_def.txt 里 CLANG_BIN"
grep -n "CLANG_BIN" /home/unixnu/code/umi-work-pin/out/unixnu/umi/edk2-conf/tools_def.txt | head -6
echo "== 模板里对照"
grep -n "DEFINE CLANG_BIN" /home/unixnu/code/Mu_Basecore/BaseTools/Conf/tools_def.template | head -4
echo "== 生成的 GNUmakefile 里编译器路径（第一条）"
GM=/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/GNUmakefile
grep -n "clang-edk2" $GM 2>/dev/null | head -2 | cut -c1-200
echo "== 有没有带斜杠的写法"
grep -c "clang-edk2/" $GM 2>/dev/null
echo "== builder 里 firmware.py 怎么设 CLANG_BIN"
grep -rn "CLANG_BIN" /home/unixnu/code/umi-work-pin/sources/UniXNU/ 2>/dev/null | head -10
} > /mnt/e/Code/HackIos/out/probes/edk2-clangbin.txt 2>&1
echo WROTE
