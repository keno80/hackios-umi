#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/mac-half.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
S=/home/unixnu/code/UniXNU-main
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
CLT=/opt/unixnu-linux/CommandLineTools
FAKEROOT=$CLT/SDKs/iPhoneOS.sdk

say "== 1. 装 apfsprogs 看有没有 mkfs.apfs =="
DEBIAN_FRONTEND=noninteractive apt-get install -y apfsprogs >/tmp/apfs-install.log 2>&1
say "apt rc=$?"
tail -5 /tmp/apfs-install.log >> "$OUT"
dpkg -L apfsprogs 2>/dev/null | grep -E 'bin/' >> "$OUT" || say "apfsprogs 未装/无 bin"
say "-- 有没有 mkfs 类 --"
command -v mkfs.apfs fsck.apfs apfs-fuse apfs-dump 2>&1 >> "$OUT"

say
say "== 2. 假 SDK 里有没有 TargetConditionals.h =="
say "FAKEROOT=$FAKEROOT exists=$(test -d "$FAKEROOT" && echo YES || echo NO)"
find "$FAKEROOT" -maxdepth 3 -name 'TargetConditionals.h' 2>/dev/null >> "$OUT" || say none
say "-- audit 要的路径是 sdk/usr/include/TargetConditionals.h --"
say "direct -> $(test -f "$FAKEROOT/usr/include/TargetConditionals.h" && echo YES || echo NO)"
say "-- 全盘搜（限 deep 4）--"
find /opt/unixnu-linux -maxdepth 6 -name 'TargetConditionals.h' 2>/dev/null | head -5 >> "$OUT"

say
say "== 3. Apple 专有的警告项我们的 clang 吃不吃（audit 里那串 -W）=="
CC=$(ls /opt/unixnu-linux/CommandLineTools/bin/clang* /opt/unixnu-linux/llvm/bin/clang-24 2>/dev/null | head -1)
say "CC=$CC"
printf 'int main(void){return 0;}\n' > /tmp/wtest.c
for f in -Wno-unnecessary-virtual-specifier -Wno-c99-designator -Wno-reorder-init-list -Wno-deprecated-enum-enum-conversion; do
  say "$f -> $($CC -target arm64-apple-ios17.0 -Wextra -Werror $f -c /tmp/wtest.c -o /tmp/wtest.o 2>&1 | head -2 | tr '\n' ' ' ; echo rc=$?)"
done

say
say "== 4. make-data-seed 的完整造盘段 =="
sed -n '1,30p' "$S/scripts/make-data-seed.py" >> "$OUT" 2>&1
sed -n '30,100p' "$S/scripts/make-data-seed.py" >> "$OUT" 2>&1

say
say "== 5. 仓库里有没有 Linux 侧的 APFS 通路（NXSB/apfs）=="
grep -rln 'NXSB' "$S/scripts" "$T/scripts" /home/unixnu/code/umi-work-pin/tools 2>/dev/null | head -10 >> "$OUT"
grep -rn 'apfs' "$S/scripts/unixnu" 2>/dev/null | head -20 >> "$OUT"
say "-- seed 身份 json 的写法 --"
grep -rn 'NXSB\|volume_uuid\|identity' "$S/scripts/make-data-seed.py" "$S/scripts/unixnu/userdata.py" 2>/dev/null | head -20 >> "$OUT"

say
say "== 6. umi 工作区现有产物：interface-audit / gdb-stop / seed =="
find /home/unixnu/code/umi-work-pin/out -maxdepth 4 \( -name '*interface-audit*' -o -name 'gdb-stop.json' -o -name '*.dbr' -o -name 'data*.json' \) 2>/dev/null | head -20 >> "$OUT"
say done
