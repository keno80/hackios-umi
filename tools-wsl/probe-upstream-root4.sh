#!/bin/bash
set -u
cd /mnt/e/Code/HackIos || exit 1
G="git -C UniXNU-main"
F=FETCH_HEAD
O=out/upstream-root-recipe3.txt
: > "$O"
{
  echo "== A. 上游顶层目录 =="
  $G ls-tree --name-only $F 2>&1 | head -40
  echo ""
  echo "== B. scripts/qemu-entry 清单 =="
  $G ls-tree -r --name-only $F -- scripts/qemu-entry 2>&1 | head -40
  echo ""
  echo "== C. build-mockfs-fixture.py 的外部依赖 =="
  $G show $F:scripts/build-mockfs-fixture.py 2>&1 | grep -n -E 'import |hdiutil|diskutil|subprocess|argparse|NXSB|mockfs|open\(' | head -30
  echo ""
  echo "== C2. build-mockfs-fixture.py 前 60 行 =="
  $G show $F:scripts/build-mockfs-fixture.py 2>&1 | head -60
  echo ""
  echo "== D. NativeRamBlock / mockfs 由谁提供、被谁选 =="
  $G grep -n -E 'NativeRamBlock|mockfs|MockFS|MOCKFS' $F -- 'docs/concepts' 'docs/devices' 'kits' 'scripts' 2>&1 | head -40
  echo ""
  echo "== E. docs/concepts/payload.md 根/ramdisk 段 =="
  $G show $F:docs/concepts/payload.md 2>&1 | sed -n '40,140p'
} >> "$O" 2>&1
echo done >> "$O" 2>&1
