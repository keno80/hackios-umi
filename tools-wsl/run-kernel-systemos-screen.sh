#!/bin/bash
# U 步之五之三：编 SystemOS + GIC/屏上诊断档内核。
# 用法：run-kernel-systemos-screen.sh
#   比 run-kernel-systemos.sh 多两枚旗标：--gic-diagnostics --screen-diagnostics。
#   目的是把 boot-progress 套件（含 static _exit_records）链进内核——
#   官方 tools/analyze_umi_systemos_qemu.py:59 无条件读 `_exit_records` 2382 字节，
#   本档之前没链它，所以官方件整份跑不出 analysis.json（不是判据不过，是读不到址）。
# 契约：build_umi_xnu.py:70 要求 --screen-diagnostics 必须同给 --gic-diagnostics；
#   :114-122 把装配树里 build-xnu-4k-baseline.sh 的「必须有 UFS/owner-root/Virtio/source-corecrypto」
#   四条件闸换成「UMI_FULL_BOOT_PROGRESS=1」单条件闸（用 text.index 定位，不命中直接抛）；
#   :327 之后要求 report 里有 tree/build/boot-progress/build-report.json。
# 一件必须提前铺的东西：scripts/build-boot-progress.py:73 把
#   out/umi-xnu/umi/kernel/kernel.macho 当 provider inventory（只 xcrun nm -g -U -j 读已定义全局），
#   件不在就 `Missing actual provider inventory` 停手。umi 流水线从不产这个文件名
#   （产物叫 qemu-prelink-source-kernel.macho），所以下面用上一档 --systemos 的源内核铺一份，
#   并把「用的是哪件、sha 多少」记进旁生件，不冒充上游自己生成的 qualified 件。
set -u
source /usr/local/bin/unixnu-env
WS=/home/unixnu/code/umi-work-pin
TREE=$WS/out/umi-xnu/umi/tree
KERNEL_DIR=$WS/out/umi-xnu/umi/kernel
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

# systemos 档要的三枚上游补丁 + 本机 trace 补丁 + boot-progress 套件源，缺一枚就停手
for p in sources/UniXNU/patches/xnu/offline-owner-systemos-mount.patch \
         sources/UniXNU/patches/xnu/offline-owner-boot-manifest.patch \
         sources/UniXNU/patches/xnu/native-4k-signature-hash-cache.patch \
         devices/umi/patches/umi-xnu/zzzzzzzzzzzzz-umi-systemos-trace.patch; do
  [ -f "$WS/$p" ] || { echo "停手：缺 $p"; exit 1; }
done
for f in BootProgress.c BootProgressCore.h; do
  [ -f "$WS/devices/umi/package/boot-progress/$f" ] || { echo "停手：boot-progress 缺 $f"; exit 1; }
done

SN=$WS/out/umi-qemu/29-aes-live-metadata
if [ ! -f "$SN/gdb-stop.json" ]; then
  SRC=$WS/out/umi-qemu/run-51b-aes-live-abi/gdb-stop.json
  [ -f "$SRC" ] || { echo "停手：没有活体快照 $SRC"; exit 1; }
  mkdir -p "$SN" && cp -f "$SRC" "$SN/gdb-stop.json"
  echo "落名：$SRC -> $SN/gdb-stop.json"
fi

# boot-progress 的反汇编守门件按 macOS Homebrew 位置点名 llvm-objdump，本机靠 shim 对齐
# （唯一出处 tools-wsl/sync-helpers.sh，重启后由 reboot-restore.sh 重装）
[ -x /opt/homebrew/opt/llvm/bin/llvm-objdump ] || {
  echo "停手：缺 /opt/homebrew/opt/llvm/bin/llvm-objdump，先跑 reboot-restore.sh（或 sync-helpers.sh 那段 shim）"; exit 1; }

# provider inventory：kernel.macho 不在就用最近的源内核铺一份；已在就原样留着（可能是别人铺的）
INV=$KERNEL_DIR/kernel.macho
SEED=$KERNEL_DIR/qemu-prelink-source-kernel.macho
NM=$CLT/bin/nm
[ -x "$NM" ] || { echo "停手：缺 $NM（判符号必须用 cctools 那份 nm）"; exit 1; }
[ -f "$SEED" ] || { echo "停手：没有可当 inventory 的源内核 $SEED"; exit 1; }
if [ ! -f "$INV" ]; then
  cp -f "$SEED" "$INV"
  seed_sha=$(sha256sum "$SEED" | cut -d' ' -f1)
  n_native=$("$NM" -g -U -j "$INV" 2>/dev/null | grep -c '^_native_')
  n_exit=$("$NM" -n "$INV" 2>/dev/null | grep -c '_exit_records')
  cat > "$KERNEL_DIR/kernel.macho.provider-inventory.json" <<EOF
{
  "why": "scripts/build-boot-progress.py:73 要求 kernel/kernel.macho 存在，只用它做 nm -g -U -j 的已定义全局清单",
  "role": "provider inventory only, not an upstream-qualified kernel",
  "seed_source": "out/umi-xnu/umi/kernel/qemu-prelink-source-kernel.macho",
  "seed_sha256": "$seed_sha",
  "seed_tier": "上一档 --systemos（owner-root trust + crypto-bootstrap prelinked + native-ufs）的源内核",
  "native_globals": $n_native,
  "exit_records_in_inventory": $n_exit,
  "note": "inventory 里 native_* 全局是「本档能否看到对应视图」的依据；_exit_records 为 0 是预期的——它由本档新链进的 boot-progress 套件定义"
}
EOF
  echo "铺 inventory：$SEED -> $INV（sha=$seed_sha native_*=$n_native _exit_records=$n_exit）"
else
  echo "已存在 $INV，sha=$(sha256sum "$INV" | cut -c1-16)… 不动它"
fi

LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
mkdir -p "$LOGD"
ts=$(date +%Y%m%d-%H%M%S)
LOG=$LOGD/kernel-systemos-screen-$ts.log
echo "$LOG" > "$LOGD/kernel-systemos-screen-latest.txt"
cd "$WS" || exit 1
ensure-dev-bind || exit 1
setsid nohup python3 -u tools/build_umi_xnu.py --stage kernel --profile qemu \
  --crypto-bootstrap prelinked --native-ufs --owner-root trust --systemos \
  --gic-diagnostics --screen-diagnostics -j 5 \
  > "$LOG" 2>&1 < /dev/null &
echo $! > "$LOGD/kernel-systemos-screen.pid"
sleep 12
pid=$(cat "$LOGD/kernel-systemos-screen.pid")
if kill -0 "$pid" 2>/dev/null; then
  echo "RUNNING systemos-screen pid=$pid LOG=$LOG"
else
  echo "EXITED EARLY"
  tail -40 "$LOG"
fi
