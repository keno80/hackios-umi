#!/bin/bash
# M 步：编带 23z（EL0 IN/OUT 逐 svc 上屏）的内核。
# 与 run-kernel-cold.sh 同 env，只去掉 --early-trace —— 产物回到 source-kernel.macho，QEMU 可验。
set -u
source /usr/local/bin/unixnu-env
WS=/home/unixnu/code/umi-work-pin
TREE=$WS/out/umi-xnu/umi/tree
FAKEROOT=$TREE/.cache/fakeroot
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
CLT=$TC/CommandLineTools/usr
XCTC=$TC/XcodeDefault.xctoolchain/usr
export PATH="$CLT/bin:$TC/bin:$PATH"
export LC_ALL=C CLT_PREFIX=$CLT XCTOOLCHAIN_PREFIX=$XCTC
export XNU_TOOLCHAIN_BIN="$CLT/bin $XCTC/bin"
export UNIXNU_SDKROOT=$FAKEROOT UNIXNU_SDK_VERSION=17.0
export UNIXNU_PLATFORM_PATH=$FAKEROOT/Platforms/iPhoneOS.platform
export CROSS_CLANG=$TC/llvm/bin/clang DARWIN_TRIPLE=arm64-apple-ios17.0
export CROSS_EXTRA_FLAGS="-mllvm -disable-atexit-based-global-dtor-lowering"
export CCC_OVERRIDE_OPTIONS='# +-Wno-missing-designated-field-initializers +-Wno-unused-but-set-global'
mkdir -p "$FAKEROOT"

LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
mkdir -p "$LOGD"
ts=$(date +%Y%m%d-%H%M%S)
LOG=$LOGD/kernel-walk-$ts.log
echo "$LOG" > "$LOGD/kernel-walk-latest.txt"
touch /tmp/walk-start-marker
cd "$WS" || exit 1
ensure-dev-bind || exit 1
setsid nohup python3 -u tools/build_umi_xnu.py --stage kernel --profile phone \
  --mockfs-root -j 5 > "$LOG" 2>&1 &
echo $! > "$LOGD/kernel-walk.pid"
sleep 12
pid=$(cat "$LOGD/kernel-walk.pid")
if kill -0 "$pid" 2>/dev/null; then
  echo "RUNNING pid=$pid LOG=$LOG"
else
  echo "EXITED EARLY"
  tail -25 "$LOG"
fi
