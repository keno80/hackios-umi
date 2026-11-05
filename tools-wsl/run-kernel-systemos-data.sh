#!/bin/bash
# U 步之七之四：编 SystemOS + screen 诊断 + --pmgr + --data-ramdisk 档内核（Data 面第一次进内核）
# 用法：run-kernel-systemos-data.sh [种子 .dbr，默认 out/umi/data-seed/data-512.dbr]
#   与 run-kernel-systemos-pmgr.sh 只差一枚 --data-ramdisk，但这一枚会：
#     1) 打开 XNU_NATIVE_RAM_BLOCK / XNU_OWNER_DATA_MOUNT / XNU_SOURCE_MOCKFS（build_umi_xnu.py:147-148）
#     2) 把种子的卷 UUID 钉成 XNU_OWNER_DATA_VOLUME_UUID（:150，所以 UUID 漂了必须重编）
#     3) 自己跑 tools/build_umi_data_display.py --component ram 编 NativeRamBlock（:296-298），
#        再要求 tree/build/native-ram-block/build-report.json（:336-337）
#   要答的问题只有一个，且很值钱：**Apple 原版 APFS 驱动认不认 Linux（mkapfs）造的容器**。
#     认 -> 内容缺口（卷里没 /private/var）才是唯一剩下的事，可用内核侧 bootstrap 或 Mac 真种子补
#     不认 -> 直接转 Mac 造种子（public 仓的 GitHub macOS runner 或本机 VMware macOS VM）
#   本档种子是 mkapfs 空卷（512 MiB logical / 73,840 B 编码，契约自检 PASS，见 out/probes/u234、本脚本头部），
#     所以预期挂点停在 native_owner_data_stage 的 lookup 一步（ENOENT），不是失败——stage/ready 两位才是证据。
# 前置闸沿用 pmgr 档那份（补丁/kit/shim/inventory/契约预审计一枚枚验）。
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

SEED=${1:-$WS/out/umi/data-seed/data-512.dbr}
JSON=${SEED%.dbr}.json

# 前置件一枚枚闸，缺就停手
for p in sources/UniXNU/patches/xnu/offline-owner-systemos-mount.patch \
         sources/UniXNU/patches/xnu/offline-owner-boot-manifest.patch \
         sources/UniXNU/patches/xnu/native-4k-signature-hash-cache.patch \
         devices/umi/patches/umi-xnu/zzzz-umi-pmgr.patch \
         devices/umi/patches/umi-xnu/zzzzzzzzzzzzz-umi-systemos-trace.patch \
         devices/umi/patches/umi-xnu/zzzzzzzzzzzzzz-umi-persistent-data-userspace.patch \
         devices/umi/package/data-store/packed_ramdisk.py \
         devices/umi/package/data-store/NativeRamBlock/NativeRamBlock.cpp \
         tools/build_umi_data_display.py; do
  [ -f "$WS/$p" ] || { echo "停手：缺 $p"; exit 1; }
done
for f in kits/umi/UmiPlatformPower.cpp scripts/build-umi-platform-power.py; do
  [ -f "$TREE/$f" ] || { echo "停手：缺 $TREE/$f"; exit 1; }
done
for f in BootProgress.c BootProgressCore.h; do
  [ -f "$WS/devices/umi/package/boot-progress/$f" ] || { echo "停手：boot-progress 缺 $f"; exit 1; }
done
DONOR=$WS/out/umi-xnu/ipsw/21H461/kernelcache.decompressed
[ -f "$DONOR" ] || { echo "停手：缺 donor $DONOR"; exit 1; }
[ -f /opt/homebrew/opt/llvm/bin/llvm-objdump ] || {
  echo "停手：缺 /opt/homebrew/opt/llvm/bin/llvm-objdump，先跑 reboot-restore.sh"; exit 1; }
[ -x /usr/local/bin/llvm-objcopy ] && [ -f /usr/local/lib/umi/macho-globalize.py ] || {
  echo "停手：缺 llvm-objcopy Mach-O shim（跑 sync-helpers.sh）"; exit 1; }

# 种子先按 build 侧那三条闸自验一遍，别把四十分钟浪费在一个不合规的输入上
[ -f "$SEED" ] && [ -f "$JSON" ] || { echo "停手：缺种子 $SEED 或身份件 $JSON（先跑 make-umi-data-seed-linux.sh）"; exit 1; }
python3 - "$SEED" "$JSON" "$WS/devices/umi/package/data-store/packed_ramdisk.py" <<'PY' || { echo "停手：种子不合 build 契约"; exit 1; }
import importlib.util, json, pathlib, sys
spec = importlib.util.spec_from_file_location('pr', sys.argv[3]); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
actual, header = m.inspect(pathlib.Path(sys.argv[1]))
identity = json.loads(pathlib.Path(sys.argv[2]).read_text())
bad = [k for k in actual if actual[k] != identity.get(k)]
assert actual.get('packed') and header[32:36] == b'NXSB' and identity.get('volume_uuid'), \
    f'闸不过：packed={actual.get("packed")} magic={header[32:36]!r} uuid={identity.get("volume_uuid")}'
assert not bad, f'.json 与 inspect 不符：{bad}'
print(f'  种子合规：logical={actual["bytes"]} 编码={actual["encoded_bytes"]} 卷 UUID={identity["volume_uuid"]}')
PY

INV=$KERNEL_DIR/kernel.macho
NM=$CLT/bin/nm
[ -x "$NM" ] || { echo "停手：缺 $NM（判符号必须用 cctools 那份 nm）"; exit 1; }
if [ ! -f "$INV" ]; then
  for CAND in qemu-systemos-pmgr.macho qemu-systemos-screen.macho; do
    [ -f "$KERNEL_DIR/$CAND" ] && { cp -f "$KERNEL_DIR/$CAND" "$INV"; cp -f "$KERNEL_DIR/${CAND%.macho}.json" "$KERNEL_DIR/kernel.json"; echo "铺 inventory：$CAND -> $INV"; break; }
  done
fi
[ -f "$INV" ] || { echo "停手：没有可当 inventory 的 prelinked 件"; exit 1; }
[ -f "$KERNEL_DIR/kernel.json" ] || { echo "停手：$INV 缺同名 kernel.json"; exit 1; }
echo "== candidate inventory =="
sha256sum "$INV" | cut -c1-64 | sed 's/^/  /'
sha256sum "$SEED" | cut -c1-64 | sed 's/^/  种子 sha=/'

AUDIT=$TREE/scripts/audit-umi-pmgr-contract.py
[ -f "$AUDIT" ] || { echo "停手：缺 $AUDIT"; exit 1; }
AUDIT_OUT=$TREE/build/umi-platform-power
mkdir -p "$AUDIT_OUT"
echo "== 预审计 $AUDIT =="
( cd "$WS" && python3 "$AUDIT" --candidate "$INV" --donor "$DONOR" \
    --output "$AUDIT_OUT/contract-audit-pre-data.json" ) 2>&1 | tail -12
PRE_AUDIT=${PIPESTATUS[0]}
echo "  预审计 exit=$PRE_AUDIT"
[ "$PRE_AUDIT" = 0 ] || { echo "停手：candidate 没通过 PMGR 契约审计"; exit 1; }

LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
mkdir -p "$LOGD"
ts=$(date +%Y%m%d-%H%M%S)
LOG=$LOGD/kernel-systemos-data-$ts.log
echo "$LOG" > "$LOGD/kernel-systemos-data-latest.txt"
cd "$WS" || exit 1
ensure-dev-bind || exit 1
setsid nohup python3 -u tools/build_umi_xnu.py --stage kernel --profile qemu \
  --crypto-bootstrap prelinked --native-ufs --owner-root trust --systemos \
  --gic-diagnostics --screen-diagnostics --pmgr --data-ramdisk "$SEED" -j 5 \
  > "$LOG" 2>&1 < /dev/null &
echo $! > "$LOGD/kernel-systemos-data.pid"
sleep 15
pid=$(cat "$LOGD/kernel-systemos-data.pid")
if kill -0 "$pid" 2>/dev/null; then
  echo "RUNNING systemos-data pid=$pid LOG=$LOG"
else
  echo "EXITED EARLY"
  tail -40 "$LOG"
fi
