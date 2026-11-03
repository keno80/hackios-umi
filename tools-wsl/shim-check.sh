#!/bin/bash
# 一次性核对：xcrun shim 能力 + storage-providers 里 candidate 是谁
export PATH=/opt/unixnu-linux/CommandLineTools/usr/bin:/opt/unixnu-linux/bin:/usr/local/bin:/usr/bin:/bin
export LC_ALL=C
cd /home/unixnu/code/umi-work-pin || exit 1
{
  echo "== xcrun shim"
  command -v xcrun ar c++filt nm clang
  echo "-- xcrun --sdk iphoneos --show-sdk-path"
  xcrun --sdk iphoneos --show-sdk-path 2>&1 | head -3
  echo "-- xcrun ar --version"
  xcrun ar --version 2>&1 | head -2
  echo "-- xcrun c++filt -n（测符号还原）"
  echo __ZN9IOService10gMetaClassE | xcrun c++filt -n 2>&1 | head -2
  echo "########## build_umi_storage_providers.py 40..92（candidate 定义）"
  sed -n '40,92p' tools/build_umi_storage_providers.py
} > /mnt/e/Code/HackIos/out/shim-check.txt 2>&1
echo WROTE
