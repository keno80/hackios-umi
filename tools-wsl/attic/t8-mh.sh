#!/bin/bash
# T 步判据前置（三）：本树里 MH_* 到底是几（决定内核认不认这个 dyld）
set -u
exec > /mnt/e/Code/HackIos/out/probes/t8-mh.txt 2>&1
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
FR=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/fakeroot
source /usr/local/bin/unixnu-env 2>/dev/null
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}

echo "== 1. 内核构建树里所有 MH_* 定义 =="
grep -rn 'define MH_' "$X" 2>/dev/null | grep -v Binary | head -30
echo "-- 内核里 filetype 判定的另一处：validate_macho_header / MH_EXECUTE 用法 --"
grep -rn 'MH_EXECUTE\|MH_FILESET\|MH_KEXT_BUNDLE' "$X/bsd/kern/mach_loader.c" | head -20

echo
echo "== 2. CLT/SDK 侧的 loader.h =="
find "$TC" "$FR" -name 'loader.h' -path '*mach-o*' 2>/dev/null | head -5
for f in $(find "$TC" "$FR" -name 'loader.h' -path '*mach-o*' 2>/dev/null | head -3); do
  echo "-- $f --"; grep -n 'define MH_' "$f" | head -20
done

echo
echo "== 3. otool 的 filetype 表（llvm 里怎么映射的）=="
strings -a "$TC/CommandLineTools/usr/bin/otool" 2>/dev/null | grep -n -A14 -B2 '^OBJECT$' | head -30
echo "-- 直接问 otool：造一个 filetype=6 与 7 的对照不划算，改看 macho_dump 的枚举串 --"
strings -a "$TC/CommandLineTools/usr/bin/otool" 2>/dev/null | grep -E '^(EXECUTE|DYLINKER|BUNDLE|FILESET|KEXT_BUNDLE|DSYM|DYLIB|PRELOAD|CORE|OBJECT|DYLIB_STUB|FVMLIB)$' | head -20
echo "== done $(date -u +%FT%TZ)"
