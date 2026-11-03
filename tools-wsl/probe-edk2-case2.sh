#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/edk2-case2.txt
LOG=/home/unixnu/code/umi-work-pin/out/umi-fw-run-01/cli.log
{
  echo "== cli.log 大小/时间"
  ls -l "$LOG"
  echo
  echo "== cli.log 末尾 60 行"
  tail -60 "$LOG"
  echo
  echo "== 含 mismatch / error 的原始行（不截断）"
  grep -n "mismatch\|error\|ERROR" "$LOG" | head -20
  echo
  echo "== SecureBoot-Keys.inc 位置"
  find /home/unixnu/code/uefi-umi-b -name 'SecureBoot-Keys.inc' 2>/dev/null | head
  echo
  echo "== 该文件 124 行附近"
  f=$(find /home/unixnu/code/uefi-umi-b -name 'SecureBoot-Keys.inc' 2>/dev/null | head -1)
  [ -n "$f" ] && sed -n '115,130p' "$f"
  echo
  echo "== 固件构建的 PACKAGES_PATH / WORKSPACE 设置"
  grep -rn "PACKAGES_PATH\|WORKSPACE\|Mu_Basecore" /home/unixnu/code/UniXNU-pin/scripts/linux/*uefi* 2>/dev/null | head -20
  grep -rn "PACKAGES_PATH\|packages-path\|Mu_Basecore" /home/unixnu/code/UniXNU-pin/unixnu 2>/dev/null | head -20
  echo
  echo "== run-uefi-fw.sh 全文"
  cat /mnt/e/Code/HackIos/tools-wsl/run-uefi-fw.sh
} > "$OUT" 2>&1
echo WROTE
