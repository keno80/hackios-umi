#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/mockfs-fixture-build.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
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

say "== 0. 打补丁 =="
python3 /mnt/e/Code/HackIos/tools-wsl/patch-mockfs-switch.py >> "$OUT" 2>&1
say "patch rc=$?"
say "-- --help 里的新开关 --"
cd "$WS" && python3 tools/build_umi_xnu.py --help 2>&1 | grep -A2 'mockfs-root' >> "$OUT"

say
say "== 1. fakeroot 里有没有 TargetConditionals.h（E 步的最后一个未知项）=="
say "fakeroot exists=$(test -d "$FAKEROOT" && echo YES || echo NO)"
find "$FAKEROOT" -name 'TargetConditionals.h' 2>/dev/null | head -3 >> "$OUT"
say "-- fakeroot/usr/include 前 15 项 --"
ls "$FAKEROOT/usr/include" 2>/dev/null | head -15 >> "$OUT"

say
say "== 2. 单独跑 build-mockfs-fixture.py =="
cd "$TREE" || exit 1
timeout 600 python3 scripts/build-mockfs-fixture.py >> "$OUT" 2>&1
say "fixture rc=$?"
say "-- 产物 --"
ls -l "$TREE/build/mockfs-fixture/" 2>&1 >> "$OUT"

say
say "== 3. 归档里的符号 =="
A=$TREE/build/mockfs-fixture/libmockfs_fixture.a
if [ -f "$A" ]; then
  xcrun nm -g "$A" 2>&1 | grep -E 'mockfs_mountroot|mockfs_vfsops|T |_mockfs' | head -20 >> "$OUT"
  say "-- 编译日志尾（有警告也看得到）--"
  for f in "$TREE"/build/mockfs-fixture/*.log; do say "-- $f --"; tail -3 "$f" >> "$OUT"; done
fi
say done
