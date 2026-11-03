#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/codesign-shim.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
S=/home/unixnu/code/UniXNU-main
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:$PATH"

say "== 1. fixture 脚本里 codesign 与解析段（95-130）=="
sed -n '95,130p' "$S/scripts/build-native-user-fixture.py" >> "$OUT" 2>&1

say
say "== 2. codesign 是什么（真二进制还是 shim）=="
file "$(command -v codesign)" >> "$OUT" 2>&1
say "-- 若是脚本，前 40 行 --"
head -40 "$(command -v codesign)" 2>/dev/null >> "$OUT"

say
say "== 3. 实测 codesign --display --verbose=4 的输出 =="
codesign --display --verbose=4 "$S/build/native-user-fixture-umi/launchd.macho" 2>&1 | head -30 >> "$OUT"
say "-- verify --"
codesign --verify --strict "$S/build/native-user-fixture-umi/launchd.macho" 2>&1 | head -5 >> "$OUT"

say
say "== 4. IOFindBSDRoot 的 RAMDisk -> mdevadd 完整段 =="
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
sed -n '845,890p' "$X/iokit/bsddev/IOKitBSDInit.cpp" >> "$OUT" 2>&1
say done
