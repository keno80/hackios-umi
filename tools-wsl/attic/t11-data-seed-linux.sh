#!/bin/bash
# 判据：Data 种子这三步到底是不是只有 Mac 能做（Linux 侧有没有等价写入通路）
set -u
exec > /mnt/e/Code/HackIos/out/probes/t11-data-seed-linux.txt 2>&1
U=/home/unixnu/code/UniXNU-main

echo "== 1. 三个脚本在哪、Mac 专用调用是哪几行 =="
for s in make-data-seed.py seed-data-grow.py prepare-owner-data-fixture.py seed-data-skip-setup.py; do
  f=$(find "$U" /home/unixnu/code/umi-work-pin -maxdepth 5 -name "$s" 2>/dev/null | head -1)
  echo "-- $s -> $f"
  [ -n "$f" ] && grep -n 'hdiutil\|diskutil\|ditto\|plutil\|defaults write\|mount\|xcrun\|/Volumes' "$f" | head -14
done

echo
echo "== 2. Data 种子里到底放了什么（要写的内容清单）=="
for s in prepare-owner-data-fixture.py seed-data-skip-setup.py make-data-seed.py; do
  f=$(find "$U" -maxdepth 5 -name "$s" 2>/dev/null | head -1)
  [ -n "$f" ] && { echo "-- $f --"; grep -n 'Path(\|mkdir\|write_bytes\|write_text\|Preferences\|\.plist' "$f" | head -20; }
done

echo
echo "== 3. Linux 侧可用的 APFS 写入器 =="
for b in mkfs.apfs apfsck dump-apfs fsapfsapfsinfo apfs-fuse fuse-apfs; do
  printf '%-16s %s\n' "$b" "$(command -v "$b" || echo -)"
done
echo "-- apt 里有哪些候选 --"
apt-cache search apfs 2>/dev/null | head -10
echo "-- apfsprogs 装了哪些二进制 --"
dpkg -L apfsprogs 2>/dev/null | grep -E 'bin/' | head
echo "-- pip 侧 --"
python3 -c "import pyfsapfs; print('pyfsapfs', pyfsapfs.__file__)" 2>&1 | head -2

echo
echo "== 4. 内核侧：APFS 驱动是否只读挂载（决定写进去有没有意义）=="
grep -rn 'apfs\|APFS' "$U/../umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work/bsd/vfs/vfs_apfs"* 2>/dev/null | head -5
grep -rln 'com.apple.apfs' /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work/bsd 2>/dev/null | head -5
echo "== done $(date -u +%FT%TZ)"
