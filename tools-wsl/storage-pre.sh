#!/bin/bash
# storage-providers 的 --snapshot 到底怎么用、29-aes-live-metadata 在不在
cd /home/unixnu/code/umi-work-pin || exit 1
{
  echo "== grep snapshot in build_umi_storage_providers.py"
  grep -n "snapshot" tools/build_umi_storage_providers.py
  echo "== 29-aes-live-metadata 是否存在"
  ls -l out/umi-qemu/29-aes-live-metadata 2>&1 | head -5
  echo "== out/umi-qemu 现有 run"
  ls out/umi-qemu 2>&1
  echo "== build_umi_native_ufs.py 头部 40 行"
  head -40 tools/build_umi_native_ufs.py
  echo "== 这三个脚本里有没有 macOS 专属调用"
  grep -n "hdiutil\|xcrun\|darwin\|platform.system\|ctypes" tools/build_umi_native_ufs.py tools/build_umi_root_bundle.py tools/build_umi_storage_providers.py | head -30
} > /mnt/e/Code/HackIos/out/storage-pre.txt 2>&1
echo WROTE
