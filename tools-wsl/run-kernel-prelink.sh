#!/bin/bash
# U 步之一：编 prelink 输入档内核（qemu profile + prelinked crypto bootstrap + mockfs 根）。
# 产物 out/umi-xnu/umi/kernel/qemu-prelink-source-kernel.macho，状态件 qemu-prelink-source-build-status.json。
# 与 run-kernel-walk.sh 同一套 env，只换 stage/档位开关。
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
LOG=$LOGD/kernel-prelink-$ts.log
echo "$LOG" > "$LOGD/kernel-prelink-latest.txt"
cd "$WS" || exit 1
ensure-dev-bind || exit 1
# 用 --stage kernel，不跑 bootstrap 遍：bootstrap 遍把 XNU_SOURCE_CORECRYPTO14 置 0，
# 于是 libcorecrypto 不进链接，而我们的 crypto-kit 补丁让 register_crypto.c 硬引用 ccaes_/ccdes_/
# ccchacha20poly1305_/ccrng 等符号 → ld 直接 Undefined symbols（u13/u14 取证）。
# prelinked 模式本身只给 prng_random.o 加 -UXNU_SOURCE_CORECRYPTO14，corecrypto 照常链进内核，
# 所以 stage=kernel 的产物符号齐全；build_umi_prelink.py 只核对 success/crypto_bootstrap/profile/
# early_trace，不核对 stage（u17 取证）。
# 不带 --mockfs-root：APFS 探针在 vfsinit() 之后立即触发并停在 _native_apfs_probe_checkpoint，走不到挂根。
setsid nohup python3 -u tools/build_umi_xnu.py --stage kernel --profile qemu \
  --crypto-bootstrap prelinked -j 5 > "$LOG" 2>&1 &
echo $! > "$LOGD/kernel-prelink.pid"
sleep 15
pid=$(cat "$LOGD/kernel-prelink.pid")
if kill -0 "$pid" 2>/dev/null; then
  echo "RUNNING pid=$pid LOG=$LOG"
else
  echo "EXITED EARLY"
  tail -25 "$LOG"
fi
