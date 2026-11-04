#!/bin/bash
# 侦察根卷/存储相关工具：各自要什么输入、是否依赖真机抓取
set -u
T=/home/unixnu/code/umi-work-pin/tools
OUT=/mnt/e/Code/HackIos/out/probes/root-tools.txt
{
  for t in prepare_umi_root build_umi_root_bundle check_umi_owner_root_qemu audit_umi_storage reuse_umi_storage collect_umi audit_umi_ufs_memory; do
    f=$T/$t.py
    [ -f "$f" ] || { echo "########## $t  (不存在)"; continue; }
    echo "########## $t"
    sed -n '1,12p' "$f"
    echo "  -- 参数 --"
    grep -n 'add_argument' "$f" | head -10
    echo "  -- 设备侧痕迹 --"
    grep -n 'adb\|fastboot\|by-name\|dd \|userdata\|/dev/block' "$f" | head -10
    echo
  done
} > "$OUT" 2>&1
echo WROTE
