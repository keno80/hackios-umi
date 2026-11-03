#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/n4k-delivery.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
S=/home/unixnu/code/UniXNU-main
W=/home/unixnu/code/umi-work-pin
LOGD=$S/out/unixnu-logs

say "== 0. 构建进度 =="
L=$(cat "$LOGD/kernel-mockfs-latest.txt")
pgrep -f 'build_umi_xnu.py' >/dev/null && say RUNNING || say FINISHED
tail -8 "$L" 2>&1 | tail -8 >> "$OUT"

say
say "== 1. fixture 需要的外部工具在本机是否存在 =="
source /usr/local/bin/unixnu-env 2>/dev/null
TREE=$W/out/umi-xnu/umi/tree
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
export XNU_TOOLCHAIN_BIN="$TC/CommandLineTools/usr/bin $TC/XcodeDefault.xctoolchain/usr/bin"
export PATH="$TC/CommandLineTools/usr/bin:$TC/bin:$PATH"
for t in clang ld vtool codesign ldid nm ar dwarfdump; do
  say "$t -> $(xcrun -find $t 2>/dev/null || echo MISSING)"
done
say "-- apt 里有没有 ldid --"
apt-cache policy ldid 2>&1 | head -4 >> "$OUT"

say
say "== 2. --native-user-image 的交付通路 =="
grep -n 'native_user_image\|native-user-image' "$S/scripts/probe-darwinboot-xnu.py" | head -20 >> "$OUT"

say
say "== 3. RAMDisk 交接：adt 占位与 darwinboot 填充 =="
grep -rn 'RAMDisk' "$S/scripts"/*.py 2>/dev/null | head -20 >> "$OUT"
say "-- umi 侧有没有同样的 handoff --"
grep -rn 'RAMDisk' "$W/tools" 2>/dev/null | head -15 >> "$OUT"

say
say "== 4. umi 的 payload 里能不能塞一块 RAM 镜像 =="
grep -rn 'root.img\|user_image\|native_user' "$W/tools" 2>/dev/null | head -15 >> "$OUT"
say done
