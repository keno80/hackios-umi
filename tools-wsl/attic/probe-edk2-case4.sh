#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/edk2-case4.txt
B=/home/unixnu/code/uefi-umi-b
MB=/home/unixnu/code/Mu_Basecore
{
  echo "== SecureBoot-Keys.inc 全文（只有 10 行）"
  cat -A "$B/Silicon/Silicium/SiliciumPkg/SecureBoot-Keys.inc"
  echo
  echo "== 它 include 进去的那个文件的前后（找 SecureBootKeys 之类）"
  ls "$B/Silicon/Silicium/SiliciumPkg/" | head -30
  echo
  echo "== umi.dsc 中所有 !include"
  grep -n "!include\|!subdir" "$B/Platforms/Xiaomi/umiPkg/umi.dsc" | head -20
  echo
  echo "== BaseTools 里 FILE_CASE_MISMATCH 的抛出点（只看 .py）"
  grep -rn --include='*.py' "FILE_CASE_MISMATCH" "$MB/BaseTools/Source/Python" | head -10
  echo
  echo "== PathClassFile 相关片段"
  sed -n '1,60p' "$MB/BaseTools/Source/Python/Common/PathClassFile.py" 2>/dev/null
  echo "..."
  grep -n -A 30 "def __init__" "$MB/BaseTools/Source/Python/Common/PathClassFile.py" 2>/dev/null | sed -n '1,80p'
} > "$OUT" 2>&1
echo WROTE
