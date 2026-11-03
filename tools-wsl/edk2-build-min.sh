#!/bin/bash
# 最小复现 #8 的 FILE_CASE_MISMATCH：直接用上次那次构建的环境跑 build（不重打 patch）
O=/mnt/e/Code/HackIos/out/edk2-build-A.txt
export PATH=/home/unixnu/code/clang-edk2:/usr/local/bin:/usr/bin:/bin
export CLANG_BIN=/home/unixnu/code/clang-edk2
export WORKSPACE=/home/unixnu/code/uefi-umi-b
export PACKAGES_PATH="$WORKSPACE:$WORKSPACE/Platforms/Xiaomi:/home/unixnu/code/umi-work-pin/out/unixnu/umi/tree/package:/home/unixnu/code/Mu_Basecore:$WORKSPACE/Common/Mu:$WORKSPACE/Common/Mu_OEM_Sample:$WORKSPACE/Silicon/Qualcomm:$WORKSPACE/Silicon/Silicium"
export EDK_TOOLS_PATH=/home/unixnu/code/Mu_Basecore/BaseTools
export CONF_PATH=/home/unixnu/code/umi-work-pin/out/unixnu/umi/edk2-conf
export PYTHON_COMMAND=python3
cd "$WORKSPACE" || exit 1
{
echo "== Mu_Basecore 是 symlink 还是目录"
ls -ld "$WORKSPACE/Mu_Basecore"
echo "== build 命令行"
echo "build -p Platforms/Xiaomi/umiPkg/umi.dsc -a AARCH64 -b DEBUG -t CLANGPDB -n 4 ..."
build -p Platforms/Xiaomi/umiPkg/umi.dsc -a AARCH64 -b DEBUG -t CLANGPDB -n 4 \
  -D FD_BASE=0x9fc00000 -D FD_SIZE=0x300000 -D FD_BLOCKS=768 -D ENABLE_SECUREBOOT=0 \
  -D DEVICE_MODEL=0 -D MEMORY_PROTECTION=TRUE -D SHIP_MODE=FALSE -D BUILDID_STRING=umi-menu-research
echo "rc=$?"
} > $O 2>&1
grep -nE "error|Error|FAILED|Traceback|mismatch|Build total" $O | head -25 > /mnt/e/Code/HackIos/out/edk2-build-A.sum.txt
echo WROTE
