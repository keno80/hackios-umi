#!/bin/bash
# native-ufs 步为什么找不到 IOKit/storage 头
set -u
WS=/home/unixnu/code/umi-work-pin
TREE=$WS/out/umi-xnu/umi/tree
OUT=/mnt/e/Code/HackIos/out/probes/nativeufs-probe.txt
{
  echo "== 全盘找 IOBlockStorageDevice.h"
  find /home/unixnu/code -name 'IOBlockStorageDevice.h' 2>/dev/null | head -20
  echo
  echo "== 树里 IOKit/storage 目录"
  find "$TREE" -maxdepth 6 -type d -name storage 2>/dev/null | head -20
  echo
  echo "== build_umi_native_ufs.py 里 include 的组装"
  grep -n "IOKit\|include\|-I" "$WS/tools/build_umi_native_ufs.py" 2>/dev/null | head -40
  echo
  echo "== NativeUfs.cpp 前 30 行"
  head -30 "$TREE/build/native-ufs/NativeUfs.cpp" 2>/dev/null
  echo
  echo "== NativeUfs.cpp 出处（UniXNU 仓里）"
  find /home/unixnu/code/UniXNU-pin -name 'NativeUfs.cpp' 2>/dev/null | head -5
  echo
  echo "== 谁生成 build/native-ufs 目录"
  grep -rn "native-ufs" "$WS/tools/"*.py 2>/dev/null | head -20
  echo
  echo "== fakeroot SDK 里 IOKit 头"
  find "$TREE/.cache/fakeroot" -path '*IOKit*storage*' -name '*.h' 2>/dev/null | head -10
  echo "-- fakeroot 顶层"
  ls "$TREE/.cache/fakeroot" 2>/dev/null | head
  echo
  echo "== 真实 SDK（unixnu-env 里定义的）"
  grep -n "SDK\|IOKit" /usr/local/bin/unixnu-env 2>/dev/null | head -30
} > "$OUT" 2>&1
echo WROTE
