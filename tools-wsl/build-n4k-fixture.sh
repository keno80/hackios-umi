#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/n4k-fixture-build.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
S=/home/unixnu/code/UniXNU-main
W=/home/unixnu/code/umi-work-pin
TREE=$W/out/umi-xnu/umi/tree
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
source /usr/local/bin/unixnu-env 2>/dev/null
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:$PATH"
export XNU_TOOLCHAIN_BIN="$TC/CommandLineTools/usr/bin $TC/XcodeDefault.xctoolchain/usr/bin"
export UNIXNU_SDKROOT=$TREE/.cache/fakeroot UNIXNU_SDK_VERSION=17.0
export LC_ALL=C

say "== 0. IOKitBSDInit 的 RAMDisk -> md0 =="
grep -n -B6 -A18 'RAMDisk' "$TREE/.cache/xnu-work/iokit/bsddev/IOKitBSDInit.cpp" 2>/dev/null | head -45 >> "$OUT"
say "-- 本机 PAGE_SHIFT --"
grep -rn 'define PAGE_SHIFT' "$TREE/.cache/xnu-work/osfmk/arm/"*.h 2>/dev/null | head -5 >> "$OUT"

say
say "== 1. 跑 build-native-user-fixture.py（无 probe，最小组合）=="
O=$S/build/native-user-fixture-umi
rm -rf "$O" 2>/dev/null
timeout 300 python3 "$S/scripts/build-native-user-fixture.py" --output "$O" > "$OUT".stdout 2>&1
say "rc=$?"
tail -20 "$OUT".stdout >> "$OUT"
say "-- 产物 --"
ls -la "$O" 2>/dev/null | head -20 >> "$OUT"
say done
