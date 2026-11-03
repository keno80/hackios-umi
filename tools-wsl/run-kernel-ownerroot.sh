#!/bin/bash
# 阶段6b 第一趟：qemu 档案 + crypto-bootstrap prelinked + native-ufs，出「候选内核」
# 不带 --owner-root，免得撞那个我们还没产的活元数据快照
set -u
source /usr/local/bin/unixnu-env
WS=/home/unixnu/code/umi-work-pin
NAME=${1:-or-01-bootstrap}
JOBS=${JOBS:-5}
LOGD=$WS/out/umi-xnu-build
LOG=$LOGD/$NAME.log
STATE=$WS/out/tui-state
TREE=$WS/out/umi-xnu/umi/tree
FAKEROOT=$TREE/.cache/fakeroot
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
CLT=$TC/CommandLineTools/usr
XCTC=$TC/XcodeDefault.xctoolchain/usr
mkdir -p "$LOGD" "$FAKEROOT"

export PATH="$CLT/bin:$TC/bin:$PATH"
export LC_ALL=C CLT_PREFIX=$CLT XCTOOLCHAIN_PREFIX=$XCTC
export XNU_TOOLCHAIN_BIN="$CLT/bin $XCTC/bin"
export UNIXNU_SDKROOT=$FAKEROOT UNIXNU_SDK_VERSION=17.0
export UNIXNU_PLATFORM_PATH=$FAKEROOT/Platforms/iPhoneOS.platform
export CROSS_CLANG=$TC/llvm/bin/clang DARWIN_TRIPLE=arm64-apple-ios17.0
export CROSS_EXTRA_FLAGS="-mllvm -disable-atexit-based-global-dtor-lowering"
export CCC_OVERRIDE_OPTIONS='# +-Wno-missing-designated-field-initializers +-Wno-unused-but-set-global'

cd "$WS" || exit 1
[ -d "$WS" ] || { echo "工作区不存在：$WS"; exit 1; }
ensure-dev-bind || exit 1

# 路A 本地补丁 5：bootstrap 趟也要归零 probe，否则 --native-ufs 100% 撞 crypto 闸门
python3 /mnt/e/Code/HackIos/tools-wsl/patch-umi-bootstrap-probe.py "$WS/tools/build_umi_xnu.py" || exit 1

# 面板卡片：日志面板跟 LOG= 走，PID 用来判活与「终止当前任务」
cat > "$STATE" <<EOF
PHASE=build
RUN=$NAME
TOOL=qemu 档案 / prelinked / native-ufs / -j $JOBS
LOG=$LOG
START_TS=$(date +%s)
NOTE1=第一趟：先出候选内核（不带 --owner-root，绕开未产的活元数据快照）
NOTE2=下一步=QEMU 停在 _bsd_init 抓 gdb-stop.json，再走 --owner-root audit 第二趟
TASK1=done|#14 userdata-root.img 已产出
TASK2=run|#15 第一趟 候选内核（本次 $NAME）
TASK3=wait|活元数据快照（29-aes-live-metadata）
TASK4=wait|#15 第二趟 --owner-root audit 最终链
EOF

setsid nohup python3 -u tools/build_umi_xnu.py \
  --profile qemu --crypto-bootstrap prelinked --native-ufs -j "$JOBS" > "$LOG" 2>&1 &
pid=$!
echo "PID=$pid" >> "$STATE"
sleep 12
if kill -0 "$pid" 2>/dev/null; then
  echo "运行中 pid=$pid  LOG=$LOG"
else
  echo "已退出，尾部："; tail -25 "$LOG"
  echo "PHASE=build-fail" >> "$STATE"
  exit 1
fi
echo "== 前 12 行"
head -12 "$LOG" | sed 's/^/  | /'
echo DONE
