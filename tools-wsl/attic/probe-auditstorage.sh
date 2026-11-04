#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
OUT=/mnt/e/Code/HackIos/out/probes/auditstorage-probe.txt
{
  echo "== feed IOStorageFamily 的 git HEAD"
  git -C /home/unixnu/code/UniXNU-main/out/feeds/IOStorageFamily-ad2e13e0 rev-parse HEAD 2>&1
  echo
  echo "== audit_umi_storage.py 全文"
  cat "$WS/tools/audit_umi_storage.py"
  echo
  echo "== build_umi_xnu.py 里有没有调 audit_umi_storage / storage-abi"
  grep -n "audit_umi_storage\|storage-abi\|interface-audit" "$WS/tools/build_umi_xnu.py" | head
  echo
  echo "== 文档里的顺序（umi / storage-abi）"
  grep -rn "audit_umi_storage\|storage-abi" /home/unixnu/code/UniXNU-pin/docs 2>/dev/null | head -20
  echo
  echo "== umi 设备文档里 native-ufs 段"
  grep -rn "native-ufs\|storage" "$WS/docs/zh/devices/umi.md" 2>/dev/null | head -30
  echo
  echo "== reuse_umi_storage.py 全文"
  cat "$WS/tools/reuse_umi_storage.py"
  echo
  echo "== 候选内核产物"
  ls -l "$WS/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/" 2>/dev/null | head -10
  echo "-- kernel 目录"
  ls -l "$WS/out/umi-xnu/umi/kernel/" 2>/dev/null | head
  echo
  echo "== IOPlatformExpert.cpo.json 在不在"
  ls -l "$WS/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/iokit/DEVELOPMENT/IOPlatformExpert.cpo.json" 2>&1
  echo
  echo "== TargetConditionals.h 可来源"
  ls -l "$WS/out/umi-xnu/umi/tree/.cache/fakeroot/usr/include/TargetConditionals.h" 2>&1
  ls -l /home/unixnu/code/UniXNU-pin/scripts/TargetConditionals.h 2>&1
  echo
  echo "== xcrun shim 支不支持 --sdk macosx"
  head -40 /home/unixnu/code/UniXNU-pin/scripts/linux/xcrun
} > "$OUT" 2>&1
echo WROTE
