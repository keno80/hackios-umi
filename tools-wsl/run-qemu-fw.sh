#!/bin/bash
# QEMU 固件：用 pin 树的 package + Mu_Basecore 编通用 UniXNU.efi / DarwinBoot（不碰手机）
set -u
source /usr/local/bin/unixnu-env
PIN=/home/unixnu/code/UniXNU-pin
EDK2=/home/unixnu/code/Mu_Basecore
FW=/home/unixnu/code/umi-work-pin/out/umi-qemu/firmware
mkdir -p "$FW"
export UNIXNU_EDK2=$EDK2 UNIXNU_BUILD_DIR=$FW JOBS=4
export PYTHON_COMMAND=python3
export CLANG_BIN=/opt/unixnu-linux/llvm/bin/
TOOLCHAIN=${TOOLCHAIN:-CLANGPDB}
echo "== UniXNU 包（$TOOLCHAIN）"
cd "$PIN/package" || exit 1
bash build.sh -b DEBUG -t "$TOOLCHAIN" > "$FW/build-package.log" 2>&1
echo "package exit=$?  产物：$(ls "$FW/Build/Out/AARCH64-DEBUG/" 2>/dev/null | tr '\n' ' ')"
tail -6 "$FW/build-package.log"
echo "== DarwinBoot（$TOOLCHAIN）"
export WORKSPACE="$PIN/drivers/DarwinBoot"
export PACKAGES_PATH="$PIN/drivers/DarwinBoot:$PIN/package:$EDK2"
export EDK_TOOLS_PATH="$EDK2/BaseTools"
export CONF_PATH="$FW/Build/Conf"
export PATH="$EDK_TOOLS_PATH/BinWrappers/PosixLike:$EDK_TOOLS_PATH/Source/C/bin:$PATH"
cd "$PIN/drivers/DarwinBoot" || exit 1
build -p DarwinBootPkg/DarwinBoot.dsc -a AARCH64 -b DEBUG -t "$TOOLCHAIN" -n 4 > "$FW/build-darwinboot.log" 2>&1
echo "darwinboot exit=$?"
find "$FW" -name 'DarwinBoot.efi' -printf '%p %TY-%Tm-%Td %TH:%TM\n' 2>/dev/null | head -3
tail -6 "$FW/build-darwinboot.log"
