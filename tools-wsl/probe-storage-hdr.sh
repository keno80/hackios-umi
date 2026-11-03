#!/bin/bash
set -u
TREE=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
FR=$TREE/.cache/fakeroot
OUT=/mnt/e/Code/HackIos/out/storage-hdr-probe.txt
{
  echo "== Kernel.framework Headers/IOKit 下有无 storage"
  ls "$FR/System/Library/Frameworks/Kernel.framework/Versions/A/Headers/IOKit" | head -30
  echo "-- storage 内容"
  ls "$FR/System/Library/Frameworks/Kernel.framework/Versions/A/Headers/IOKit/storage" 2>&1 | head -40
  echo
  echo "== usr/local/include 全量一层"
  ls "$FR/usr/local/include" | head -60
  echo
  echo "== usr/local/include/kernel 一层"
  ls "$FR/usr/local/include/kernel" | head -30
  echo
  echo "== EXPORT_HDRS/iokit 结构"
  ls "$TREE/build/xnu/ios-obj/EXPORT_HDRS/iokit" 2>&1 | head -20
  echo
  echo "== DriverKit/IOBlockStorageDevice.h 是否存在（IOKitUser 那个只是转发）"
  ls -l "$FR/System/Library/Frameworks/Kernel.framework/Versions/A/Headers/DriverKit/IOBlockStorageDevice.h" 2>&1
  echo
  echo "== 作者侧 xcrun shim 怎么给 -isystem"
  grep -n "isystem\|usr-local-include\|local/include\|sysroot" /home/unixnu/code/UniXNU-pin/scripts/linux/xcrun | head -20
  echo
  echo "== prepare-xnu.py 里 fakeroot/include 的搬运"
  grep -n "include" /home/unixnu/code/UniXNU-pin/scripts/linux/prepare-xnu.py | head -40
} > "$OUT" 2>&1
echo WROTE
