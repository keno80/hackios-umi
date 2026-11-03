#!/bin/bash
# 看 IOKitUser 头集合、它的自包含依赖，以及 fakeroot 现有的 include 布局
set -u
TREE=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
OUT=/mnt/e/Code/HackIos/out/iokituser-probe.txt
{
  echo "== xnu 源里的 IOKitUser 目录"
  ls "$TREE/.cache/xnu-work/iokit/IOKitUser" | head -60
  echo
  echo "== IOBlockStorageDevice.h 的 include"
  grep -n "^#import\|^#include" "$TREE/.cache/xnu-work/iokit/IOKitUser/IOBlockStorageDevice.h"
  echo
  echo "== 树里所有 <IOKit/storage/...> 形式的 include（谁还需要这批头）"
  grep -rn "IOKit/storage/" "$TREE/build/native-ufs/" 2>/dev/null | head -20
  echo
  echo "== fakeroot/usr/local/include 现状"
  find "$TREE/.cache/fakeroot/usr/local/include" -maxdepth 1 2>/dev/null | head -20
  echo
  echo "== fakeroot Kernel.framework Headers 顶层"
  ls "$TREE/.cache/fakeroot/System/Library/Frameworks/Kernel.framework/Versions/A/Headers" 2>/dev/null | head -20
  echo
  echo "== 谁造 fakeroot（含 IOKitUser 的搬运逻辑）"
  grep -rln "fakeroot" /home/unixnu/code/UniXNU-pin/scripts /home/unixnu/code/UniXNU-pin/kits 2>/dev/null | head -10
  echo
  echo "== 造 SDK 头的脚本里 IOKitUser/storage 关键字"
  grep -rn "IOKitUser\|storage" /home/unixnu/code/UniXNU-pin/scripts/*sdk* /home/unixnu/code/UniXNU-pin/scripts/*fakeroot* 2>/dev/null | head -20
} > "$OUT" 2>&1
echo WROTE
