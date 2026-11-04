#!/bin/bash
# 读 storage-providers 的 candidate/snapshot 逻辑，和 run_umi_qemu 支持的停点/内存抓取
cd /home/unixnu/code/umi-work-pin || exit 1
{
  echo "########## build_umi_storage_providers.py 90..160"
  sed -n '90,160p' tools/build_umi_storage_providers.py
  echo "########## run_umi_qemu.py 里 memory/stop 相关参数"
  grep -n "memory\|--stop\|bsd_init\|snapshot" tools/run_umi_qemu.py | head -30
  echo "########## gdb-stop.py 抓 memory 的开关"
  grep -n "add_argument" devices/umi/bringup/tools/gdb-stop.py 2>/dev/null | head -40 || \
  grep -rn "add_argument" sources/UniXNU/scripts/qemu-entry/gdb-stop.py | head -40
} > /mnt/e/Code/HackIos/out/probes/snapshot-flow.txt 2>&1
echo WROTE
