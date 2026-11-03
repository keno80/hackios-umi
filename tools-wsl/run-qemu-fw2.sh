#!/bin/bash
# 用 GCC5 交叉编 QEMU 用的通用 UniXNU.efi + DarwinBoot（edk2 / Mu_Basecore）
set -u
source /usr/local/bin/unixnu-env
EDK2=/home/unixnu/code/Mu_Basecore
FW=/home/unixnu/code/umi-work-pin/out/umi-qemu/firmware
mkdir -p "$FW"
export UNIXNU_EDK2=$EDK2 UNIXNU_BUILD_DIR=$FW JOBS=4 PYTHON_COMMAND=python3
export GCC_AARCH64_PREFIX=aarch64-linux-gnu- GCC5_AARCH64_PREFIX=aarch64-linux-gnu-
echo "== UniXNU 包（GCC5）"
cd /home/unixnu/code/UniXNU-main/package || exit 1
bash build.sh -b DEBUG -t GCC5 > "$FW/build-package-gcc.log" 2>&1
echo "package exit=$? 产物=$(ls "$FW/Build/Out/AARCH64-DEBUG/" 2>/dev/null | tr '\n' ' ')"
tail -8 "$FW/build-package-gcc.log"
echo "== DarwinBoot（GCC5）"
D=$(readlink -f /home/unixnu/code/UniXNU-main/drivers/DarwinBoot)
export WORKSPACE=$D
export PACKAGES_PATH="$D:/home/unixnu/code/UniXNU-main/package:$EDK2"
export EDK_TOOLS_PATH=$EDK2/BaseTools
export CONF_PATH=$FW/Build/Conf
export PATH=$EDK_TOOLS_PATH/BinWrappers/PosixLike:$EDK_TOOLS_PATH/Source/C/bin:$PATH
cd "$D" || exit 1
build -p DarwinBootPkg/DarwinBoot.dsc -a AARCH64 -b DEBUG -t GCC5 -n 4 > "$FW/build-darwinboot-gcc.log" 2>&1
echo "darwinboot exit=$?"
find "$FW" -name 'DarwinBoot.efi' -printf '%p\n' 2>/dev/null | head -3
tail -8 "$FW/build-darwinboot-gcc.log"
