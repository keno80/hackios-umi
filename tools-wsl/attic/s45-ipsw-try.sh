#!/bin/bash
# 接 s44：ipsw 装好（/mnt/d/tools/ipsw/ipsw）。本文件直接在 21H461 的两个 DMG 上试解，
# 目标是拿到真 Apple EL0 件 /usr/lib/dyld 与 /sbin/launchd。语法未知就先把 help 抓全，再挨个试、留错误原文。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s45-ipsw-try.txt 2>&1
IPSW=/mnt/d/tools/ipsw/ipsw
IMG=/home/unixnu/code/umi-work-pin/out/umi-xnu/ipsw/21H461
CX=$IMG/044-76034-038.dmg
OS=$IMG/044-76040-038.dmg
W=/mnt/e/Code/HackIos/refer
OUT=/home/unixnu/code/umi-work-pin/out/umi-xnu/apple-el0
mkdir -p "$OUT"

echo "== 0. 手上有没有整包 IPSW（ipsw extract --files 吃整包最省事）=="
find /home/unixnu -maxdepth 5 -name '*.ipsw' -printf '%s\t%p\n' 2>/dev/null | head
ls -l "$W" 2>/dev/null | head

echo
echo "== 1. 相关子命令 help =="
for c in "disk dmg --help" "disk hfs --help" "pkg --help" "mount --help"; do
  echo "--- ipsw $c ---"; timeout 60 $IPSW $c 2>&1 | head -35
done
echo "--- ipsw extract --help 的 flags 段 ---"
timeout 60 $IPSW extract --help 2>&1 | sed -n '/^Flags:/,$p' | head -40

echo
echo "== 2. 试 cryptex（裸 bvx 块图）=="
for cmd in "disk dmg --list $CX" "disk dmg $CX" "pkg $CX" "disk dmg --extract $CX --out $OUT/cx"; do
  echo "--- ipsw $cmd ---"
  timeout 300 $IPSW $cmd 2>&1 | head -25
done

echo
echo "== 3. 试 OS dmg =="
for cmd in "disk dmg --list $OS" "pkg $OS"; do
  echo "--- ipsw $cmd ---"
  timeout 300 $IPSW $cmd 2>&1 | head -25
done

echo
echo "== 4. mount 支不支持非 macOS =="
timeout 120 $IPSW mount --help 2>&1 | head -30
echo "--- 直接试挂载（只读）---"
timeout 240 $IPSW mount "$CX" --force 2>&1 | head -25
find "$OUT" -maxdepth 3 2>/dev/null | head -20

echo
echo "== 5. 收尾：列出并卸掉 loop 挂载，别留残留 =="
losetup -l 2>&1 | head -10
mount | grep -E 'loop|apfs' | head -10
for m in $(mount | awk '/\/tmp\/|\/var\/folders|loop/{print $3}' | head -5); do
  echo "  尝试 umount $m"; timeout 30 umount "$m" 2>&1 | head -2
done
timeout 60 $IPSW mount --unmount 2>&1 | head -10
losetup -l 2>&1 | head -5

