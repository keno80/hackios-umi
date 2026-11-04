#!/bin/bash
# T 步判据前置（二）：用工具链自己的 otool 复核真文件头，并定死 LC_LOAD_DYLINKER 的编号
set -u
exec > /mnt/e/Code/HackIos/out/probes/t7-otool.txt 2>&1
EL=/home/unixnu/code/umi-work-pin/out/umi-xnu/apple-el0
X=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
source /usr/local/bin/unixnu-env 2>/dev/null
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
CLT=$TC/CommandLineTools/usr
export PATH="$CLT/bin:$TC/bin:$PATH"

echo "== 1. 头 32 字节原样 =="
for f in launchd dyld; do
  echo "-- $f --"; od -An -tx4 -N32 "$EL/$f"
done

echo
echo "== 2. otool -hv（工具链自己怎么解读 filetype）=="
for f in launchd dyld; do
  echo "-- $f --"; "$CLT/bin/otool" -hv "$EL/$f" 2>&1 | head -6
done

echo
echo "== 3. otool -l 里的 dylinker / main / signature =="
for f in launchd dyld; do
  echo "-- $f --"
  "$CLT/bin/otool" -l "$EL/$f" 2>/dev/null | grep -A3 -E 'cmd LC_(LOAD_DYLINKER|ID_DYLINKER|MAIN|CODE_SIGNATURE|FILETYPE)' | head -30
done

echo
echo "== 4. loader.h 里 LC_LOAD_DYLINKER / LC_ID_DYLINKER / MH_DYLINKER 的编号 =="
grep -rn 'define LC_LOAD_DYLINKER\|define LC_ID_DYLINKER\|define MH_DYLINKER\|define MH_BUNDLE' \
  "$X/mach-o/loader.h" "$X/EXTERNAL_HEADERS/mach-o/loader.h" 2>/dev/null | head

echo
echo "== 5. 内核 mach_loader.c 对 dyld 的两处 filetype 判定上下文 =="
sed -n '2300,2320p' "$X/bsd/kern/mach_loader.c"
echo "--"
sed -n '2515,2535p' "$X/bsd/kern/mach_loader.c"
echo "-- 880..900（MH_DYLINKER case）--"
sed -n '878,900p' "$X/bsd/kern/mach_loader.c"

echo
echo "== 6. load_dylinker 是否强制 filetype =="
grep -n -A24 'load_dylinker(load_command' "$X/bsd/kern/mach_loader.c" | head -40
echo "== done $(date -u +%FT%TZ)"
