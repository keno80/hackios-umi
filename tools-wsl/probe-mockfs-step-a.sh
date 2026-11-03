#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/mockfs-step-a.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
U=/home/unixnu/code/UniXNU-umi
W=/home/unixnu/code/umi-work-pin
T=$W/out/umi-xnu/umi/tree

say "== 1. build-mockfs-fixture.py 的真实位置 =="
find /home/unixnu/code -maxdepth 7 -name 'build-mockfs-fixture.py' 2>/dev/null >> "$OUT"

say
say "== 2. build_umi_xnu.py 里 MOCKFS/RAM_BLOCK 的绑定点（两份副本）=="
for f in "$U/tools/build_umi_xnu.py" "$W/tools/build_umi_xnu.py"; do
  say "-- $f --"
  grep -n 'XNU_SOURCE_MOCKFS\|XNU_NATIVE_RAM_BLOCK\|XNU_OWNER_DATA_MOUNT\|mockfs' "$f" 2>/dev/null | head -20 >> "$OUT"
done

say
say "== 3. 现有内核里有没有 mockfs 符号（用 xcrun nm 走 Mach-O nm）=="
K=$(ls -t $W/out/umi-xnu/umi/kernel/*.macho $T/build/xnu/*.macho 2>/dev/null | head -1)
say "K=$K"
if [ -n "$K" ]; then
  export XNU_TOOLCHAIN_BIN="/opt/unixnu-linux/CommandLineTools/usr/bin /opt/unixnu-linux/CommandLineTools/bin"
  say "-- nm 用的哪个 --"
  /usr/bin/xcrun -find nm 2>&1 >> "$OUT"
  timeout 120 /usr/bin/xcrun nm "$K" 2>&1 | grep -ciE 'mockfs' >> "$OUT"
  timeout 120 /usr/bin/xcrun nm "$K" 2>&1 | grep -iE 'mockfs|vfs_mountroot_apfsfs|root_file_provider' | head -12 >> "$OUT"
fi

say
say "== 4. defconfig 现状与 mockfs 相关开关 =="
grep -nE 'MOCKFS|RAM_BLOCK|OWNER_DATA|UFS|VIRTIO_BLOCK' "$U/configs/umi_defconfig" 2>/dev/null >> "$OUT"

say
say "== 5. XNU_SOURCE_MOCKFS 在构建系统里怎么变成 -DMOCKFS =="
grep -rn 'XNU_SOURCE_MOCKFS\|MOCKFS' "$T/scripts/build-xnu-4k-baseline.sh" 2>/dev/null | head -20 >> "$OUT"
grep -rn 'SOURCE_MOCKFS' "$T/scripts"/*.py 2>/dev/null | head -10 >> "$OUT"
say done
