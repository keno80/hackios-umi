#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/edk2-case-probe.txt
UEFI=/home/unixnu/code/uefi-umi-b
{
  echo "== 上次固件构建日志里的报错上下文"
  for f in /home/unixnu/code/UniXNU-umi-out/cli.log /mnt/e/Code/HackIos/out/umi-fw-run-01/cli.log; do
    [ -f "$f" ] && { echo "-- $f"; grep -n "case mismatch\|error 0010\|build.py\|Traceback" "$f" | head -10; }
  done
  echo
  echo "== 最新 cli.log 找法"
  find /home/unixnu/code /mnt/e/Code/HackIos/out -maxdepth 4 -name 'cli.log' -newermt '2026-11-01' 2>/dev/null | head -5
  echo
  echo "== MdeLibs.dsc.inc 真实位置与拼写"
  find /home/unixnu/code -maxdepth 6 -iname 'MdeLibs.dsc.inc' 2>/dev/null | head -10
  echo
  echo "== Mu_Basecore 顶层目录名（大小写）"
  ls /home/unixnu/code | head -30
  ls /home/unixnu/code/Mu_Basecore 2>/dev/null | head -20
  echo
  echo "== uefi-umi-b 顶层（哪个是 edk2）"
  ls "$UEFI" 2>/dev/null | head -30
  echo
  echo "== SecureBoot-Keys.inc 第 110..130 行"
  sed -n '110,130p' "$UEFI/Silicon/Silicium/SiliciumPkg/SecureBoot-Keys.inc" 2>&1
  echo
  echo "== 是否存在 MdePkg 于 uefi-umi-b 里"
  ls -d "$UEFI/MdePkg" 2>&1 | head -3
} > "$OUT" 2>&1
echo WROTE
