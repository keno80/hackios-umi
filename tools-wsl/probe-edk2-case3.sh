#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/edk2-case3.txt
B=/home/unixnu/code/uefi-umi-b
{
  echo "== uefi-umi-b/Mu_Basecore 是什么"
  ls -ld "$B/Mu_Basecore"
  echo
  echo "== SecureBoot-Keys.inc 行数与 118..130"
  wc -l "$B/Silicon/Silicium/SiliciumPkg/SecureBoot-Keys.inc"
  sed -n '118,130p' "$B/Silicon/Silicium/SiliciumPkg/SecureBoot-Keys.inc" | cat -A | head -20
  echo
  echo "== 谁发出 'File name case mismatch'"
  grep -rn "File name case mismatch" "$B/Mu_Basecore/BaseTools/Source/Python" 2>/dev/null | head -5
  grep -rn "File name case mismatch" /home/unixnu/code/Mu_Basecore/BaseTools/Source/Python 2>/dev/null | head -5
  echo
  echo "== 相关函数上下文"
  f=$(grep -rl "File name case mismatch" /home/unixnu/code/Mu_Basecore/BaseTools/Source/Python 2>/dev/null | head -1)
  echo "file=$f"
  [ -n "$f" ] && n=$(grep -n "File name case mismatch" "$f" | head -1 | cut -d: -f1) && sed -n "$((n>40?n-40:1)),$((n+6))p" "$f"
  echo
  echo "== umi.dsc 里 SecureBoot-Keys 的 include 方式"
  grep -rn "SecureBoot-Keys\|MdeLibs.dsc.inc" "$B/Platforms/Xiaomi/umiPkg/umi.dsc" 2>/dev/null | head -10
  echo
  echo "== Conf 里的 PACKAGES_PATH/工具版本"
  ls /home/unixnu/code/umi-work-pin/out/unixnu/umi/edk2-conf 2>&1 | head
  echo
  echo "== build 命令用的 build 是哪个（PATH farm）"
  head -5 /home/unixnu/code/clang-edk2/../*.txt 2>/dev/null | head -3
  command -v build; ls -l "$(command -v build)" 2>&1 | head -3
} > "$OUT" 2>&1
echo WROTE
