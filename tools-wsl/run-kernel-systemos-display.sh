#!/bin/bash
# U 步之九之四：编 SystemOS + screen 诊断 + --pmgr + --data-ramdisk + --legacy-display 档内核
# 用法：run-kernel-systemos-display.sh [种子 .dbr，默认 out/umi/data-seed/data-mac64.dbr]
#   与 run-kernel-systemos-data.sh 只差一枚 --legacy-display，但这一枚会：
#     1) 打开 XNU_NATIVE_LEGACY_DISPLAY=1、并把 XNU_NATIVE_MOBILE_DISPLAY 钉死 0（build_umi_xnu.py:156-157）
#     2) 让构建自己再跑一次官方 build_umi_data_display.py --component display（:296-298），
#        所以 brew/--prefix llvm 影子与 display-reference.macho 必须在位——这是本机首次真跑那条链
#     3) 把 tree/build/native-legacy-display/libNativeLegacyDisplay.late.a 当 provider 进
#        boot-progress 清单（build-boot-progress.py:83-84），_native_legacy_* 仪表由
#        LegacyDisplayProbe.o 定义（u495 实测），弱引用不再被 NULL 掉
#     4) 报告里多一节 legacy_display_build（:340-341），status JSON 的 legacy_display 转真——
#        这正是 build_umi_prelink.py:79-81 自动追加三枚显示根的开关
#   硬要求（同一件 argparse 里读死的）：--systemos（且 owner-root=trust）+ --screen-diagnostics
#     （且 --gic-diagnostics）；--data-ramdisk 也要求 --systemos，官方取证件还断言三件同开
#     （run_umi_data_display_qemu.py:25）。所以种子沿用 49 档那枚 data-mac64（UUID FB5F1CA2…），
#     单变量只剩显示 provider 本身。
# 前置闸沿用 data 档那份（补丁/kit/shim/inventory/契约预审计一枚枚验），另加 display 归档自检。
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

SEED=${1:-$WS/out/umi/data-seed/data-mac64.dbr}
JSON=${SEED%.dbr}.json

# 前置件一枚枚闸，缺就停手
for p in sources/UniXNU/patches/xnu/offline-owner-systemos-mount.patch \
         sources/UniXNU/patches/xnu/offline-owner-boot-manifest.patch \
         sources/UniXNU/patches/xnu/native-4k-signature-hash-cache.patch \
         devices/umi/patches/umi-xnu/zzzz-umi-pmgr.patch \
         devices/umi/patches/umi-xnu/zzzzzzzzzzzzz-umi-systemos-trace.patch \
         devices/umi/patches/umi-xnu/zzzzzzzzzzzzzz-umi-persistent-data-userspace.patch \
         devices/umi/patches/umi-xnu/optional-legacy-display.patch \
         devices/umi/package/data-store/packed_ramdisk.py \
         devices/umi/package/data-store/NativeRamBlock/NativeRamBlock.cpp \
         tools/build_umi_data_display.py tools/run_umi_data_display_qemu.py \
         tools/analyze_umi_data_display_qemu.py; do
  [ -f "$WS/$p" ] || { echo "停手：缺 $p"; exit 1; }
done
for f in kits/umi/UmiPlatformPower.cpp scripts/build-umi-platform-power.py \
         kits/umi/legacy-display/LegacyDisplayProbe.cpp kits/umi/legacy-display/KeyStoreProbe.cpp \
         drivers/NativeMobileDisplay/NativeLegacyDisplay.cpp drivers/NativeMobileDisplay/NativeGOPPresenter.cpp \
         drivers/NativeKeyStoreEvents/NativeKeyStoreEvents.cpp; do
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
# display 档专属：brew --prefix llvm 必须应答，且应答目录里 llvm-objcopy 要指向 Mach-O shim
BP=$(brew --prefix llvm 2>/dev/null) || { echo "停手：brew --prefix llvm 不应答（跑 sync-helpers.sh）"; exit 1; }
[ -e "$BP/bin/llvm-objcopy" ] || { echo "停手：$BP/bin/llvm-objcopy 不在位"; exit 1; }
echo "  display 工具入口：$(readlink -f "$BP/bin/llvm-objcopy")"
# 参照件与同名报告在位（构建期 display() 会自己再验一遍 sha，这里先闸掉明显缺失）
REF=$KERNEL_DIR/display-reference.macho
if [ ! -f "$REF" ] || [ ! -f "${REF%.macho}.json" ]; then
  echo "停手：缺 $REF 或 ${REF%.macho}.json（先跑 run-display-reference.sh）"; exit 1
fi

# 种子先按 build 侧那三条闸自验一遍，别把四十分钟浪费在一个不合规的输入上
[ -f "$SEED" ] && [ -f "$JSON" ] || { echo "停手：缺种子 $SEED 或身份件 $JSON"; exit 1; }
python3 - "$SEED" "$JSON" "$WS/devices/umi/package/data-store/packed_ramdisk.py" <<'PY' || { echo "停手：种子不合 build 契约"; exit 1; }
import importlib.util, json, pathlib, sys
spec = importlib.util.spec_from_file_location('pr', sys.argv[3]); m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
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
  for CAND in qemu-systemos-data-mac64.macho qemu-systemos-pmgr.macho qemu-systemos-screen.macho; do
    [ -f "$KERNEL_DIR/$CAND" ] && { cp -f "$KERNEL_DIR/$CAND" "$INV"; cp -f "$KERNEL_DIR/${CAND%.macho}.json" "$KERNEL_DIR/kernel.json"; echo "铺 inventory：$CAND -> $INV"; break; }
  done
fi
[ -f "$INV" ] || { echo "停手：没有可当 inventory 的 prelinked 件"; exit 1; }
[ -f "$KERNEL_DIR/kernel.json" ] || { echo "停手：$INV 缺同名 kernel.json"; exit 1; }
echo "== candidate inventory =="
sha256sum "$INV" | cut -c1-64 | sed 's/^/  /'
sha256sum "$SEED" | cut -c1-64 | sed 's/^/  种子 sha=/'

# display 归档：已编过就自校 sha（构建期会重跑一次 display()，这里是早停手，不是跳过）
DOUT=$TREE/build/native-legacy-display
if [ -f "$DOUT/build-report.json" ]; then
  python3 - "$DOUT" <<'PY' || { echo "停手：display 归档报告自洽性不符"; exit 1; }
import hashlib, json, pathlib, sys
d = pathlib.Path(sys.argv[1])
r = json.loads((d / "build-report.json").read_text())
arc = d / "libNativeLegacyDisplay.late.a"
assert arc.is_file(), "缺归档本体"
h = hashlib.sha256(arc.read_bytes()).hexdigest()
assert h == r.get("archive_sha256"), f"archive sha 不符：{h} != {r.get('archive_sha256')}"
print(f"  display 归档在位且自洽：{arc.stat().st_size} B  {h[:16]}…")
print(f"  reference_candidate = {r.get('reference_candidate')}")
print(f"  original_candidate_sha256 = {r.get('original_candidate_sha256')}")
PY
fi

AUDIT=$TREE/scripts/audit-umi-pmgr-contract.py
[ -f "$AUDIT" ] || { echo "停手：缺 $AUDIT"; exit 1; }
AUDIT_OUT=$TREE/build/umi-platform-power
mkdir -p "$AUDIT_OUT"
echo "== 预审计 $AUDIT =="
( cd "$WS" && python3 "$AUDIT" --candidate "$INV" --donor "$DONOR" \
    --output "$AUDIT_OUT/contract-audit-pre-display.json" ) 2>&1 | tail -12
PRE_AUDIT=${PIPESTATUS[0]}
echo "  预审计 exit=$PRE_AUDIT"
[ "$PRE_AUDIT" = 0 ] || { echo "停手：candidate 没通过 PMGR 契约审计"; exit 1; }

LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
mkdir -p "$LOGD"
ts=$(date +%Y%m%d-%H%M%S)
LOG=$LOGD/kernel-systemos-display-$ts.log
echo "$LOG" > "$LOGD/kernel-systemos-display-latest.txt"
cd "$WS" || exit 1
ensure-dev-bind || exit 1
setsid nohup python3 -u tools/build_umi_xnu.py --stage kernel --profile qemu \
  --crypto-bootstrap prelinked --native-ufs --owner-root trust --systemos \
  --gic-diagnostics --screen-diagnostics --pmgr --legacy-display --data-ramdisk "$SEED" -j 5 \
  > "$LOG" 2>&1 < /dev/null &
echo $! > "$LOGD/kernel-systemos-display.pid"
sleep 15
pid=$(cat "$LOGD/kernel-systemos-display.pid")
if kill -0 "$pid" 2>/dev/null; then
  echo "RUNNING systemos-display pid=$pid LOG=$LOG"
else
  echo "EXITED EARLY"
  tail -40 "$LOG"
fi
