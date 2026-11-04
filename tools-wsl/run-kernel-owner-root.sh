#!/bin/bash
# U 步之三：编 owner-root 档内核——把真 Apple APFS 根只读挂上（QEMU 资格化）。
# 用法：run-kernel-owner-root.sh [audit|trust]
#   audit = XNU_OWNER_ROOT_AUDIT=1, TRUST=0（挂上但拒绝，应 panic "rootvp not authenticated…"）
#   trust = 两者都 1（owner binding 接受，这是通往 SystemOS union/dyld cache 的那一档）
# 与 run-kernel-walk.sh 同 env；差别：profile=qemu + prelinked crypto + native-ufs + owner-root，且不挂 mockfs 假根。
set -u
MODE=${1:-audit}
case "$MODE" in audit|trust) ;; *) echo "用法: $0 [audit|trust]"; exit 2 ;; esac

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
# 这一档会在编排里顺带编 native-ufs / storage-providers，那两个独立编译的命令行没有
# -Wno-unnecessary-virtual-specifier / -Wno-deprecated-enum-enum-conversion（内核自己的 CFLAGS 有），
# 所以要和 run-native-ufs.sh、run-storage-providers.sh 用同一份四旗标；两旗标会在 native-ufs 步 -Werror 退出。
export CCC_OVERRIDE_OPTIONS='# +-Wno-missing-designated-field-initializers +-Wno-unused-but-set-global +-Wno-unnecessary-virtual-specifier +-Wno-deprecated-enum-enum-conversion'
mkdir -p "$FAKEROOT"

# storage-providers 步官方写死吃 out/umi-qemu/29-aes-live-metadata/gdb-stop.json；
# 本机的活体快照在 run-51b。落名只做复制，候选 sha 一致性仍由 providers 步自己校验——
# 快照与 qemu-native-ufs-trace.macho 不是同一件时它会自己停手，不会静默错绑。
SN=$WS/out/umi-qemu/29-aes-live-metadata
if [ ! -f "$SN/gdb-stop.json" ]; then
  SRC=$WS/out/umi-qemu/run-51b-aes-live-abi/gdb-stop.json
  [ -f "$SRC" ] || { echo "停手：没有活体快照 $SRC，先跑 run-storage-providers.sh live"; exit 1; }
  mkdir -p "$SN" && cp -f "$SRC" "$SN/gdb-stop.json"
  echo "落名：$SRC -> $SN/gdb-stop.json"
fi

LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
mkdir -p "$LOGD"
ts=$(date +%Y%m%d-%H%M%S)
LOG=$LOGD/kernel-owner-root-$MODE-$ts.log
echo "$LOG" > "$LOGD/kernel-owner-root-latest.txt"
touch /tmp/owner-root-start-marker
cd "$WS" || exit 1
ensure-dev-bind || exit 1
setsid nohup python3 -u tools/build_umi_xnu.py --stage kernel --profile qemu \
  --crypto-bootstrap prelinked --native-ufs --owner-root "$MODE" -j 5 \
  > "$LOG" 2>&1 < /dev/null &
echo $! > "$LOGD/kernel-owner-root.pid"
sleep 12
pid=$(cat "$LOGD/kernel-owner-root.pid")
if kill -0 "$pid" 2>/dev/null; then
  echo "RUNNING mode=$MODE pid=$pid LOG=$LOG"
else
  echo "EXITED EARLY mode=$MODE"
  tail -30 "$LOG"
fi
