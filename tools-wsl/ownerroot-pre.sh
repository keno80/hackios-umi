#!/bin/bash
# 检查 owner-root audit 内核的前置条件是否齐
{
  cd /home/unixnu/code/umi-work-pin || exit 1
  echo "== UniXNU pin 树里的 xnu 补丁"
  ls sources/UniXNU/patches/xnu/ 2>&1 | head -30
  echo "== offline-owner-root-binding-audit.patch"
  ls -l sources/UniXNU/patches/xnu/offline-owner-root-binding-audit.patch 2>&1
  echo "== defconfig 关键项"
  grep -n "NATIVE_PAN\|DT_PANIC_REGION\|NATIVE_UFS\|OWNER_ROOT\|VIRTIO" devices/umi/configs/umi_defconfig 2>&1
  echo "== 已存在的 .config（上次构建留下的）"
  find out/umi-xnu -maxdepth 3 -name ".config" 2>/dev/null | head -3
  for f in $(find out/umi-xnu -maxdepth 3 -name ".config" 2>/dev/null | head -2); do
    echo "-- $f"; grep -n "NATIVE_PAN\|DT_PANIC_REGION" "$f" 2>&1 | head -5
  done
  echo "== storage provider 构建脚本用的工具"
  head -40 tools/build_umi_storage_providers.py
  echo "== prepare_umi_root_policy.py 头部"
  head -20 tools/prepare_umi_root_policy.py
  echo "== 现有内核产物"
  ls -l out/umi-xnu/umi/kernel/ 2>&1 | head -12
} > /mnt/e/Code/HackIos/out/probes/ownerroot-pre.txt 2>&1
echo WROTE
