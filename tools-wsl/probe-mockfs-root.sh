#!/bin/bash
set -u
cd /mnt/e/Code/HackIos || exit 1
O=out/mockfs-root-path.txt
: > "$O"
{
  echo "== A. patches 里 mockfs / md0 / mount_root 的痕迹 =="
  grep -rn -E 'mockfs|md0|mount_root|mountroot' UniXNU-main/patches 2>/dev/null | head -40
  echo ""
  echo "== B. 哪些配置真的写了 rd=md0（全仓）=="
  grep -rn -E 'rd=md0|root=disk|root=md' UniXNU-main 2>/dev/null | grep -v -E '\.md:|device-records' | head -30
  echo ""
  echo "== C. 文档里写 rd=md0 的板子（看完整 args）=="
  grep -rn -E 'rd=md0' UniXNU-main/docs 2>/dev/null | head -20
  echo ""
  echo "== D. probe-darwinboot-xnu.py 的 --native-user 与相关档 =="
  grep -n -E 'native.user|md0|mockfs|initrd|def add_argument|hvf|macos' UniXNU-main/scripts/probe-darwinboot-xnu.py 2>&1 | head -40
  echo ""
  echo "== E. linux shim 目录（xcrun 等）=="
  ls -1 UniXNU-main/scripts/linux 2>&1 | head -20
  echo ""
  echo "== F. mockfs 是否在 XNU 源里已存在（umi 工作树）=="
  ls -1 /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work/bsd/miscfs/mockfs 2>&1 | head -10
  echo "-- md 设备源 --"
  ls -1 /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work/bsd/dev/md* 2>&1 | head -5
} >> "$O" 2>&1
echo done >> "$O" 2>&1
