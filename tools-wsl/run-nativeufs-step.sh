#!/bin/bash
# 单跑 native-ufs 步（不重跑整条内核链），快速探下一闸
set -u
source /usr/local/bin/unixnu-env
WS=/home/unixnu/code/umi-work-pin
TREE=$WS/out/umi-xnu/umi/tree
FAKEROOT=$TREE/.cache/fakeroot
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
CLT=$TC/CommandLineTools/usr
XCTC=$TC/XcodeDefault.xctoolchain/usr
OUT=/mnt/e/Code/HackIos/out/nativeufs-step.txt
export PATH="$CLT/bin:$TC/bin:$PATH"
export LC_ALL=C CLT_PREFIX=$CLT XCTOOLCHAIN_PREFIX=$XCTC
export XNU_TOOLCHAIN_BIN="$CLT/bin $XCTC/bin"
export UNIXNU_SDKROOT=$FAKEROOT UNIXNU_SDK_VERSION=17.0
export UNIXNU_PLATFORM_PATH=$FAKEROOT/Platforms/iPhoneOS.platform
export CROSS_CLANG=$TC/llvm/bin/clang DARWIN_TRIPLE=arm64-apple-ios17.0
export CROSS_EXTRA_FLAGS="-mllvm -disable-atexit-based-global-dtor-lowering"
# 路A 本地补丁 6：导出头 OSSymbol.h 里的 final 类 + virtual 触发 -Werror，公开 SDK 头不当作系统头
export CCC_OVERRIDE_OPTIONS='# +-Wno-missing-designated-field-initializers +-Wno-unused-but-set-global +-Wno-unnecessary-virtual-specifier'
cd "$WS" || exit 1
ensure-dev-bind || exit 1
{
  echo "== 补 storage-abi 公开头"
  python3 /mnt/e/Code/HackIos/tools-wsl/make-storage-abi-headers.py
  echo
  echo "== 单跑 tools/build_umi_native_ufs.py --profile qemu"
  python3 -u tools/build_umi_native_ufs.py --profile qemu 2>&1 | tail -60
} > "$OUT" 2>&1
echo DONE
