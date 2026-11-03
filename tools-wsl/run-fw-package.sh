#!/bin/bash
# QEMU 固件第一步：用 GCC5 交叉编 UniXNU.efi（edk2 通用包，不碰手机）
set -u
source /usr/local/bin/unixnu-env
FW=/home/unixnu/code/umi-work-pin/out/umi-qemu/firmware
mkdir -p "$FW"
export UNIXNU_EDK2=/home/unixnu/code/Mu_Basecore
export UNIXNU_BUILD_DIR=$FW
export JOBS=4
cd /home/unixnu/code/UniXNU-main/package || exit 1
L=$FW/build-package-gcc.log
bash build.sh -b DEBUG -t GCC > "$L" 2>&1
echo "build.sh exit=$?"
tail -20 "$L"
echo "== 产物 =="
ls -la "$FW/Build/Out/AARCH64-DEBUG/" 2>/dev/null | head -10
