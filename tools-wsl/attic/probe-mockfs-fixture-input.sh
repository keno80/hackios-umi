#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/mockfs-fixture-input.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
W=/home/unixnu/code/umi-work-pin

say "== 1. build-mockfs-fixture.py 全文 =="
cat "$T/scripts/build-mockfs-fixture.py" >> "$OUT" 2>&1

say
say "== 2. build_umi_xnu.py 的 130..165（settings 绑定区）=="
sed -n '128,168p' "$W/tools/build_umi_xnu.py" >> "$OUT" 2>&1

say
say "== 3. build_umi_xnu.py 的 285..315（fixture 触发区）=="
sed -n '285,315p' "$W/tools/build_umi_xnu.py" >> "$OUT" 2>&1

say
say "== 4. fixture 依赖的编译记录在不在 =="
for f in build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/bsd/DEVELOPMENT/vfs_conf.o.json \
         build/mockfs-fixture/libmockfs_fixture.a; do
  say "$f -> $(test -e "$T/$f" && echo YES || echo NO)"
done
say "-- mockfs 源文件在不在 --"
ls "$T/.cache/xnu-work/bsd/miscfs/mockfs/" 2>&1 | head -10 >> "$OUT"
say done
