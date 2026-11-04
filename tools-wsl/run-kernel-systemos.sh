#!/bin/bash
# U 步之五：编 SystemOS 档内核——原版 SystemOS cryptex 只读 union + 认证过的 dyld cache 启动。
# 用法：run-kernel-systemos.sh
#   这是通往「dyld 找到 shared cache」的那一档：--systemos 会把
#   XNU_OWNER_CACHE_MOUNT / OWNER_CACHE_STARTUP / OWNER_BOOT_MANIFEST /
#   OWNER_UNION_SYSTEMOS / NATIVE_CS_HASH_CACHE 全打开。
# 前置：owner-root trust 的活体快照已就位（同 run-kernel-owner-root.sh 那段落名）。
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
export CCC_OVERRIDE_OPTIONS='# +-Wno-missing-designated-field-initializers +-Wno-unused-but-set-global +-Wno-unnecessary-virtual-specifier +-Wno-deprecated-enum-enum-conversion'
mkdir -p "$FAKEROOT"

# 上游 systemos 档要吃的三枚补丁 + 本机 trace 补丁，先确认在位，缺一枚就停手
for p in sources/UniXNU/patches/xnu/offline-owner-systemos-mount.patch \
         sources/UniXNU/patches/xnu/offline-owner-boot-manifest.patch \
         sources/UniXNU/patches/xnu/native-4k-signature-hash-cache.patch \
         devices/umi/patches/umi-xnu/zzzzzzzzzzzzz-umi-systemos-trace.patch; do
  [ -f "$WS/$p" ] || { echo "停手：缺 $p"; exit 1; }
done

SN=$WS/out/umi-qemu/29-aes-live-metadata
if [ ! -f "$SN/gdb-stop.json" ]; then
  SRC=$WS/out/umi-qemu/run-51b-aes-live-abi/gdb-stop.json
  [ -f "$SRC" ] || { echo "停手：没有活体快照 $SRC"; exit 1; }
  mkdir -p "$SN" && cp -f "$SRC" "$SN/gdb-stop.json"
  echo "落名：$SRC -> $SN/gdb-stop.json"
fi

LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
mkdir -p "$LOGD"
ts=$(date +%Y%m%d-%H%M%S)
LOG=$LOGD/kernel-systemos-$ts.log
echo "$LOG" > "$LOGD/kernel-systemos-latest.txt"
cd "$WS" || exit 1
ensure-dev-bind || exit 1
setsid nohup python3 -u tools/build_umi_xnu.py --stage kernel --profile qemu \
  --crypto-bootstrap prelinked --native-ufs --owner-root trust --systemos -j 5 \
  > "$LOG" 2>&1 < /dev/null &
echo $! > "$LOGD/kernel-systemos.pid"
sleep 12
pid=$(cat "$LOGD/kernel-systemos.pid")
if kill -0 "$pid" 2>/dev/null; then
  echo "RUNNING systemos pid=$pid LOG=$LOG"
else
  echo "EXITED EARLY"
  tail -40 "$LOG"
fi
