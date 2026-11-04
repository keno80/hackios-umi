#!/bin/bash
# 读作者关于 owner-root / IOFindBSDRoot 的现成工具与补丁
{
  cd /home/unixnu/code/umi-work-pin || exit 1
  echo "########## check_umi_owner_root_qemu.py"
  cat tools/check_umi_owner_root_qemu.py
  echo "########## audit_umi_qemu.py 里 IOFindBSDRoot 相关"
  grep -n -B4 -A12 "IOFindBSDRoot" tools/audit_umi_qemu.py | head -80
  echo "########## umi-root-trace.patch 头部"
  head -60 devices/umi/patches/umi-xnu/zzzzz-umi-root-trace.patch
  echo "########## 补丁清单"
  ls devices/umi/patches/umi-xnu/
} > /mnt/e/Code/HackIos/out/probes/root-docs2.txt 2>&1
echo WROTE
