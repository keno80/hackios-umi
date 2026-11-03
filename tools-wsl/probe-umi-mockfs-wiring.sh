#!/bin/bash
set -u
cd /mnt/e/Code/HackIos || exit 1
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
O=out/umi-mockfs-wiring.txt
: > "$O"
{
  echo "== 1. devices/umi 是什么（软链还是实体）=="
  ls -ld "$T/devices" "$T/devices/umi" 2>&1
  echo "-- umi 目录内容 --"
  ls -1 "$T/devices/umi" 2>&1 | head -20
  echo ""
  echo "== 2. 设备仓里的 defconfig 是否在 tree 内、当前值 =="
  find "$T/devices" -name '*defconfig*' 2>/dev/null | head -10
  for f in $(find "$T/devices" -name 'umi_defconfig' 2>/dev/null | head -1); do
    echo "-- $f --"; grep -n -E 'MOCKFS|ARMCPU|SOURCE_PTHREAD|EXTRA_LD_ARCHIVES' "$f"
  done
  echo ""
  echo "== 3. kernel 构建入口与 mockfs/fixture 归档是否已在链接清单 =="
  ls -1 "$T/devices/umi/scripts" 2>&1 | head -25
  echo "-- board.toml 的 kernel 段 --"
  sed -n '1,40p' "$T/devices/umi/board.toml" 2>&1
  echo ""
  echo "== 4. base 仓 mockfs 补丁在 umi 树里的位置与是否被解析 =="
  ls -1 "$T/patches/xnu" 2>&1 | grep -i mockfs
  echo "-- 补丁解析清单（若存在）--"
  find "$T/build" -maxdepth 2 -name '*patch*' 2>/dev/null | head -10
  echo ""
  echo "== 5. build-xnu-4k-baseline.sh 中 MOCKFS 归档段（755..775）=="
  sed -n '752,780p' "$T/scripts/build-xnu-4k-baseline.sh" 2>&1 || sed -n '752,780p' UniXNU-main/scripts/build-xnu-4k-baseline.sh
  echo ""
  echo "== 6. 现有 kernel 产物与归档目录 =="
  ls -1 "$T/build" 2>&1 | head -30
  ls -1 "$T/build/mockfs-fixture" 2>&1 | head -10
} >> "$O" 2>&1
echo done >> "$O" 2>&1
