#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/linux-mac-equiv.txt
: > "$OUT"
say() { printf '%s\n' "$*" >> "$OUT"; }
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
S=/home/unixnu/code/UniXNU-main/scripts
LL=/opt/unixnu-linux/llvm/bin

say "== 0. 根文件是否真的存在（前面的 ls 都空，先核对） =="
for p in /sbin/mkfs.apfs /usr/sbin/mkfs.apfs /usr/bin/apfs /usr/sbin/fsck.apfs /lib/modules/$(uname -r)/modules.builtin; do
  say "$p -> $(test -e "$p" && echo YES || echo NO)"
done
say "uname -r -> $(uname -r)"
say "-- builtin 里有没有 apfs --"
grep -c apfs /lib/modules/$(uname -r)/modules.builtin 2>/dev/null >> "$OUT" || say "no builtin list"
dpkg -l 2>/dev/null | grep -iE 'apfs|f2fs' >> "$OUT" || say "dpkg: no apfs package"

say
say "== 1. llvm-dwarfdump 是否支持 audit 的用法 =="
ls "$LL" | grep -i dwarf >> "$OUT" 2>&1
DW=$(command -v llvm-dwarfdump || ls "$LL"/llvm-dwarfdump* 2>/dev/null | head -1)
say "DW=$DW"
if [ -n "$DW" ]; then
  "$DW" --help 2>&1 | grep -iE 'name|children' | head -20 >> "$OUT"
else
  say "llvm-dwarfdump MISSING"
fi

say
say "== 2. audit 里 dwarfdump 的确切调用与后续依赖 =="
sed -n '20,70p' "$S/audit-storage-interface.py" >> "$OUT" 2>&1
say "-- conditions/平台头 sha 的读取点（185..200）--"
sed -n '185,200p' "$S/audit-storage-interface.py" >> "$OUT" 2>&1

say
say "== 3. xcrun shim 对 --sdk macosx 的处理 =="
grep -n 'sdk\|show-sdk' "$T/scripts/linux/xcrun" 2>/dev/null | head -20 >> "$OUT"
say "-- shim 能不能跑 --sdk macosx --show-sdk-path --"
"$T/scripts/linux/xcrun" --sdk macosx --show-sdk-path 2>&1 | head -5 >> "$OUT"
"$T/scripts/linux/xcrun" --sdk macosx --show-sdk-version 2>&1 | head -5 >> "$OUT"
say "-- 系统 /usr/bin/xcrun 是不是同一个 shim --"
head -12 /usr/bin/xcrun >> "$OUT" 2>&1

say
say "== 4. APFS 造盘/扩容工具 =="
for c in mkfs.apfs apfs fsck.apfs dump.f2fs; do say "$c -> $(command -v $c || echo MISSING)"; done >> "$OUT"
apt-cache policy apfsprogs linux-apfs-rw apfs-utils 2>&1 | head -20 >> "$OUT"
say "-- 模块 --"
lsmod 2>/dev/null | grep -i apfs >> "$OUT"
modinfo apfs 2>&1 | head -3 >> "$OUT"
say "-- apt 源里有没有 apfsprogs --"
apt-cache search apfs 2>&1 | head -10 >> "$OUT"

say
say "== 5. hdiutil 那段在 Linux 的等价：仓库自带 udif/DMG 处理 =="
ls "$S"/unixnu/udif.py 2>&1 >> "$OUT"
grep -n 'def \|BLKX\|udif\|zlib\|checksum' "$S/unixnu/udif.py" 2>/dev/null | head -12 >> "$OUT"
say "-- userdata.py 的非 Darwin 分支 --"
sed -n '40,70p' "$S/unixnu/userdata.py" >> "$OUT" 2>&1

say
say "== 6. 能否拉 Apple 公开 Darwin23 IOStorageFamily 源 =="
sed -n '10,20p' "$S/audit-storage-interface.py" >> "$OUT" 2>&1
timeout 25 git ls-remote https://github.com/apple-oss-distributions/IOStorageFamily.git HEAD 2>&1 | head -3 >> "$OUT"
say done
