#!/bin/bash
# 用 pin 树 + Mu_Basecore 组 edk2 CLANGPDB：UniXNU.efi（通用 UEFI 引导）+ DarwinBoot.efi
# 输出目录完全对齐 bringup/tools/run_umi_qemu.py 期望的两个路径。
set -u
source /usr/local/bin/unixnu-env
PIN=/home/unixnu/code/UniXNU-pin
EDK2=/home/unixnu/code/Mu_Basecore
FW=/home/unixnu/code/umi-work-pin/out/umi-qemu/firmware
B=/home/unixnu/code/clang-edk2

# 全套必须同一个 LLVM：定制 clang 是 LLVM24，系统 llvm-lib 是 18，混用会在归档时
# 报 "Unknown attribute kind (102) Producer LLVM24 Reader LLVM18"。
L=/usr/lib/llvm-18/bin
mkdir -p "$B" "$FW"
# 整个 LLVM18 目录都进 farm：CLANGPDB 会用到 lld-link / llvm-dwarfutil / llvm-rc 等，
# 少一个就报 "not found"，逐个补会来回跑好几轮。
for t in "$L"/*; do ln -sf "$t" "$B/$(basename "$t")"; done
for t in ar objcopy nm ranlib; do ln -sf "$L/llvm-$t" "$B/$t"; done
echo "CLANG_BIN=$B -> $(ls "$B" | tr '\n' ' ')"
"$B/clang" --version | head -1
# 换过编译器，旧的 .obj 不能留
rm -rf "$FW/Build" "$FW/build"
[ -x "$EDK2/BaseTools/Source/C/bin/GenFw" ] || { echo "BaseTools 未编，先跑 prep-edk2b"; exit 1; }

# 让 pin 的 package/build.sh 与 DarwinBoot 的相对路径都落在同一个 WORKSPACE
ln -sfn "$PIN/package" "$FW/package"
ln -sfn "$PIN/drivers" "$FW/drivers"
ln -sfn "$EDK2" "$FW/package/Mu_Basecore"

export WORKSPACE=$FW
export EDK_TOOLS_PATH=$EDK2/BaseTools
export CONF_PATH=$FW/Build/Conf
export PYTHON_COMMAND=python3
export CLANG_BIN=$B/
export PATH=$EDK_TOOLS_PATH/BinWrappers/PosixLike:$EDK_TOOLS_PATH/Source/C/bin:$PATH
mkdir -p "$CONF_PATH"

echo "=== 1) UniXNU.efi（package/build.sh, CLANGPDB）==="
cd "$FW/package" || exit 1
UNIXNU_EDK2=$EDK2 UNIXNU_BUILD_DIR=$FW JOBS=3 \
  bash build.sh -b DEBUG -t CLANGPDB > "$FW/build-package.log" 2>&1
echo "package exit=$?"
tail -6 "$FW/build-package.log"
ls -l "$FW/Build/Out/AARCH64-DEBUG/" 2>/dev/null

echo "=== 2) DarwinBoot.efi ==="
cd "$FW" || exit 1
PACKAGES_PATH=$FW/drivers/DarwinBoot:$FW/package:$EDK2 \
  build -p drivers/DarwinBoot/DarwinBootPkg/DarwinBoot.dsc -a AARCH64 -b DEBUG -t CLANGPDB -n 3 \
  > "$FW/build-darwinboot.log" 2>&1
echo "darwinboot exit=$?"
tail -8 "$FW/build-darwinboot.log"
ls -l "$FW/build/DarwinBoot/DEBUG_CLANGPDB/AARCH64/DarwinBoot.efi" 2>/dev/null
