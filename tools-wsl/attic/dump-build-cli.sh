#!/bin/bash
# 读 build_umi_xnu.py 的 CLI 与 owner-root 分支，和我们此前建内核的脚本对照
{
  cd /home/unixnu/code/umi-work-pin || exit 1
  echo "########## build_umi_xnu.py 1..200"
  sed -n '1,200p' tools/build_umi_xnu.py
  echo "########## run-kernel-pin.sh（我们此前的建法）"
  cat /mnt/e/Code/HackIos/tools-wsl/run-kernel-pin.sh
} > /mnt/e/Code/HackIos/out/probes/build-xnu-cli.txt 2>&1
echo WROTE
