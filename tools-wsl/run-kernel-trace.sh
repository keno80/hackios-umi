#!/bin/bash
# RAM-console 里程碑版内核：--early-trace 打开 start.s/arm_init.c 的 0xB0000000 打点
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
LOG=$LOGD/kernel-trace-$ts.log
echo "$LOG" > "$LOGD/kernel-trace-latest.txt"
cd "$WS" || exit 1
ensure-dev-bind || exit 1
# 构建消费 ext4 那份 UniXNU-umi，Windows 侧改动必须先装过去，否则白跑一轮
bash /mnt/e/Code/HackIos/tools-wsl/h-install-band.sh || { echo "BAND INSTALL FAILED"; exit 1; }
setsid nohup python3 -u tools/build_umi_xnu.py --stage kernel --profile phone --early-trace -j 5 > "$LOG" 2>&1 &
echo $! > "$LOGD/kernel-trace.pid"
sleep 12
pid=$(cat "$LOGD/kernel-trace.pid")
if kill -0 "$pid" 2>/dev/null; then
  echo "RUNNING pid=$pid LOG=$LOG"
else
  echo "EXITED EARLY"
  tail -30 "$LOG"
fi
