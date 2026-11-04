#!/bin/bash
set -u
cd /mnt/e/Code/HackIos || exit 1
G="git -C UniXNU-main"
F=FETCH_HEAD
O=out/upstream-root-recipe.txt
: > "$O"
{
  echo "== 0. 上游 tip =="
  $G log -1 --format='%h %ad %s' --date=short $F 2>&1
  echo ""
  echo "== 1. 上游与 root/seed 相关的脚本清单 =="
  $G ls-tree -r --name-only $F -- scripts 2>&1 | grep -i -E 'seed|owner|data|ramdisk|apfs|fixture|root' | head -40
  echo ""
  echo "== 2. prepare-owner-data-fixture.py 全文 =="
  $G show $F:scripts/prepare-owner-data-fixture.py 2>&1
  echo ""
  echo "== 3. 板级配置里 packed_data_ramdisk / data seed 的用法 =="
  $G grep -n -E 'packed_data_ramdisk|data_seed|owner_data|ramdisk' $F -- 'devices' '*.toml' 2>&1 | head -80
} >> "$O" 2>&1
echo done >> "$O" 2>&1
