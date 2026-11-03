#!/bin/bash
# 路 A：pin 树 + 回移的 Linux 支持，跑 umi 源码内核基线（不 prelink、不碰设备）
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
LOG=$LOGD/kernel-pin-$ts.log
echo "$LOG" > "$LOGD/kernel-pin-latest.txt"
if [ ! -d "$WS" ]; then
  python3 /home/unixnu/code/UniXNU-umi/bringup/setup-workspace.py --workspace "$WS" \
    --unixnu /home/unixnu/code/UniXNU-pin --uefi /mnt/e/Code/HackIos/uefi-umi \
    --sheng /home/unixnu/code/UniXNU-sheng || { echo "setup-workspace 失败"; exit 1; }
fi
# 收据要用 p.relative_to(ROOT)，devices/umi 必须是留在工作区里的路径（bind 而非符号链接）
ensure-dev-bind || exit 1
cd "$WS" || exit 1
setsid nohup python3 -u tools/build_umi_xnu.py --profile phone -j 5 > "$LOG" 2>&1 &
echo $! > "$LOGD/kernel-pin.pid"
sleep 8
pid=$(cat "$LOGD/kernel-pin.pid")
kill -0 "$pid" 2>/dev/null && echo "路A 运行中 pid=$pid LOG=$LOG" || { echo "路A 立即退出"; tail -20 "$LOG"; }
