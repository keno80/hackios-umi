#!/bin/bash
# U 步之六之二：编 SystemOS + screen 诊断 + --pmgr 档内核。
# 用法：run-kernel-systemos-pmgr.sh
#   比 run-kernel-systemos-screen.sh 多一枚 --pmgr：把 tree/build/umi-platform-power/libUmiPlatformPower.a
#   链进内核（build_umi_xnu.py:130-131 XNU_EXTRA_LD_ARCHIVES），并在 prepare 阶段把 UMI_PMGR=1
#   写进 osfmk/arm64/umi_platform_power_config.h（:126），让 zzzz-umi-pmgr.patch 那段
#   IOPlatformExpert::start 尾部的 umi_pmgr_run() 编译进去。
# 为什么要这档：原版 AMFI 在异步 thread call 里 serviceMatching("ApplePMGRNub") 拿不到就
#   panic("AMFI: No PMGR?")——39/40 两档都停在这（上游设备仓 fuxi/marble/sirius/nx769j 等同款判词），
#   umi 树给的正解就是这条 opt-in 通路：OSKextLoadKextWithIdentifier + 原版 ApplePMGR/ApplePMGRNub
#   真身绑定 + 发布原版 nub，boot arg umi-pmgr=2 开。
# 契约：--pmgr 硬要求 --crypto-bootstrap prelinked（build_umi_xnu.py:66）；
#   :305-311 在编内核之前跑 scripts/build-umi-platform-power.py
#     --candidate out/umi-xnu/umi/kernel/kernel.macho（= 上一档的 prelinked 资格化件）
#     --donor  out/umi-xnu/ipsw/21H461/kernelcache.decompressed
#   所以 kernel.macho 必须在位；本机铺的是 qemu-systemos-screen.macho（sha 26d2019a…，
#   该件已单独过 audit-umi-pmgr-contract.py）。绑进去的绝对址来自「上一档」，
#   新件 prelink 完必须再跑一次 contract 审计，证明址没漂——那是 run-pmgr-contract-recheck 的活。
# 本机工具前置：llvm-objcopy 的 Mach-O --globalize-symbol 由 /usr/local/bin 的 shim 顶掉
#   （唯一出处 tools-wsl/sync-helpers.sh + macho-globalize.py；Ubuntu LLVM 18.1.3 本体不支持，见 u204/u207）。
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

# 前置件一枚枚闸，缺就停手（不带空壳往下跑）
for p in sources/UniXNU/patches/xnu/offline-owner-systemos-mount.patch \
         sources/UniXNU/patches/xnu/offline-owner-boot-manifest.patch \
         sources/UniXNU/patches/xnu/native-4k-signature-hash-cache.patch \
         devices/umi/patches/umi-xnu/zzzz-umi-pmgr.patch \
         devices/umi/patches/umi-xnu/zzzzzzzzzzzzz-umi-systemos-trace.patch; do
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

# 反汇编守门件按 Homebrew 位置点名 llvm-objdump；objcopy 走本机 shim
[ -x /opt/homebrew/opt/llvm/bin/llvm-objdump ] || {
  echo "停手：缺 /opt/homebrew/opt/llvm/bin/llvm-objdump，先跑 reboot-restore.sh"; exit 1; }
[ -x /usr/local/bin/llvm-objcopy ] && [ -f /usr/local/lib/umi/macho-globalize.py ] || {
  echo "停手：缺 llvm-objcopy Mach-O shim（跑 sync-helpers.sh）；否则 platform-power 停在 objcopy"; exit 1; }

# provider inventory + contract 审计的候选件：kernel/kernel.macho 必须在位
INV=$KERNEL_DIR/kernel.macho
NM=$CLT/bin/nm
[ -x "$NM" ] || { echo "停手：缺 $NM（判符号必须用 cctools 那份 nm）"; exit 1; }
if [ ! -f "$INV" ]; then
  SEED=$KERNEL_DIR/qemu-systemos-screen.macho
  [ -f "$SEED" ] || { echo "停手：没有可当 inventory 的 prelinked 件 $SEED"; exit 1; }
  cp -f "$SEED" "$INV"
  cp -f "${SEED%.macho}.json" "$KERNEL_DIR/kernel.json"
  echo "铺 inventory：$SEED -> $INV（含同名 .json，contract 审计要成对）"
fi
INV_SHA=$(sha256sum "$INV" | cut -d' ' -f1)
[ -f "$KERNEL_DIR/kernel.json" ] || { echo "停手：$INV 缺同名 kernel.json（audit 要 candidate+json 成对）"; exit 1; }
echo "== candidate inventory =="
echo "  $INV sha=$INV_SHA"
sha256sum "$DONOR" | cut -c1-64 | sed 's/^/  donor sha=/'

# 编之前先把官方 contract 审计跑一遍：址对不上就别浪费这四十分钟
# 必须用装配树里那份（tree/scripts/audit-umi-pmgr-contract.py）：它自己把 ROOT 取到 parents[1]=tree，
# 才找得到 kits/NativePrelink；devices/umi/scripts/ 那份的 parents[1] 是 devices/umi，直跑必 ModuleNotFoundError。
# 上游 instrument 也正是用 tree 那份（build-umi-platform-power.py:33）。--output 必填。
AUDIT=$TREE/scripts/audit-umi-pmgr-contract.py
[ -f "$AUDIT" ] || { echo "停手：缺 $AUDIT"; exit 1; }
echo "== 预审计 $AUDIT =="
AUDIT_OUT=$TREE/build/umi-platform-power
mkdir -p "$AUDIT_OUT"
( cd "$WS" && python3 "$AUDIT" \
    --candidate "$INV" --donor "$DONOR" \
    --output "$AUDIT_OUT/contract-audit-pre.json" ) 2>&1 | tail -20
PRE_AUDIT=${PIPESTATUS[0]}
echo "  预审计 exit=$PRE_AUDIT 报告=$AUDIT_OUT/contract-audit-pre.json"
[ "$PRE_AUDIT" = 0 ] || { echo "停手：candidate 没通过 PMGR 契约审计，绑进去的址不可信"; exit 1; }

LOGD=/home/unixnu/code/UniXNU-main/out/unixnu-logs
mkdir -p "$LOGD"
ts=$(date +%Y%m%d-%H%M%S)
LOG=$LOGD/kernel-systemos-pmgr-$ts.log
echo "$LOG" > "$LOGD/kernel-systemos-pmgr-latest.txt"
cd "$WS" || exit 1
ensure-dev-bind || exit 1
setsid nohup python3 -u tools/build_umi_xnu.py --stage kernel --profile qemu \
  --crypto-bootstrap prelinked --native-ufs --owner-root trust --systemos \
  --gic-diagnostics --screen-diagnostics --pmgr -j 5 \
  > "$LOG" 2>&1 < /dev/null &
echo $! > "$LOGD/kernel-systemos-pmgr.pid"
sleep 12
pid=$(cat "$LOGD/kernel-systemos-pmgr.pid")
if kill -0 "$pid" 2>/dev/null; then
  echo "RUNNING systemos-pmgr pid=$pid LOG=$LOG"
else
  echo "EXITED EARLY"
  tail -40 "$LOG"
fi
