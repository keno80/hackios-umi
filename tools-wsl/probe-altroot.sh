#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
UP=$WS/sources/UniXNU
OUT=/mnt/e/Code/HackIos/out/altroot-probe.txt
{
  echo "== umi_historical_receipts.py 全文（能不能取到作者的收据/审计）"
  head -60 "$WS/tools/umi_historical_receipts.py"
  echo
  echo "== 全仓引用 interface-audit 的位置"
  grep -rln "interface-audit" "$WS" 2>/dev/null | head -20
  echo
  echo "== null-root-media.patch 干什么"
  head -60 "$UP/patches/xnu/null-root-media.patch"
  echo
  echo "== mockfs 在内核里是否编进（defconfig/Kconfig）"
  grep -rn "MOCKFS\|mockfs" "$WS/devices/umi/configs/umi_defconfig" 2>/dev/null | head
  grep -rln "mockfs" "$UP/scripts" "$UP/kits" 2>/dev/null | head -10
  echo
  echo "== 树里 mockfs 源"
  find "$WS/out/umi-xnu/umi/tree/.cache/xnu-work" -iname '*mockfs*' 2>/dev/null | head -10
  echo
  echo "== run_umi_qemu.py 里 root= 相关 boot-arg 选项"
  grep -n "root=\|mockfs\|null-root\|--root" "$WS/tools/run_umi_qemu.py" 2>/dev/null | head -30
  echo
  echo "== check_umi_owner_root_qemu.py 期望的完整链条（前 60 行）"
  head -60 "$WS/tools/check_umi_owner_root_qemu.py"
} > "$OUT" 2>&1
echo WROTE
