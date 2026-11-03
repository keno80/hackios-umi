#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
OUT=/mnt/e/Code/HackIos/out/storageabi-probe.txt
{
  echo "== storage-abi/include 内容（已在编译 -I 列表里）"
  find "$WS/out/umi/storage-abi" -maxdepth 4 2>&1 | head -40
  echo
  echo "== 谁生成 storage-abi"
  grep -rln "storage-abi" "$WS/tools" 2>/dev/null | head -10
  echo
  echo "== 提及 IOStorageFamily 的文件"
  grep -rn "IOStorageFamily" "$WS/tools" /home/unixnu/code/UniXNU-pin/scripts 2>/dev/null | head -20
  echo
  echo "== IOStorageFamily feed 里的头"
  d=$(find /home/unixnu/code -maxdepth 4 -type d -name 'IOStorageFamily-*' 2>/dev/null | head -1)
  echo "dir=$d"
  ls "$d" 2>/dev/null | head -40
  echo
  echo "== NativeUfs 用到的 storage 相关符号"
  grep -n "IOBlockStorageDevice\|IOMedia\|IOMediaBlockConfiguration\|IOStorageProtocol" \
    "$WS/sources/UniXNU/drivers/NativeUfs/NativeUfs.cpp" 2>/dev/null | head -25
  echo
  echo "== UniXNU-main 那边 native-ufs 有没有成功产物（作者 Mac 之外的参照）"
  ls /home/unixnu/code/UniXNU-main/out/umi/tree/build/native-ufs 2>&1 | head -20
  echo
  echo "== pin 工作区 feeds"
  ls "$WS/out/feeds" 2>&1 | head -20
} > "$OUT" 2>&1
echo WROTE
