#!/bin/bash
set -u
OUT=/mnt/e/Code/HackIos/out/probes/providers-mockfs-probe.txt
WS=/home/unixnu/code/umi-work-pin
{
  echo "== build_umi_storage_providers.py 全文"
  cat "$WS/tools/build_umi_storage_providers.py"
  echo
  echo "== mockfs 相关：fixture 生成脚本头部"
  head -40 "$WS/sources/UniXNU/scripts/build-mockfs-fixture.py"
  echo
  echo "== 谁用 mockfs 当根（scripts 里的引用行）"
  grep -rn "mockfs" "$WS/sources/UniXNU/scripts/build-xnu-4k-baseline.sh" "$WS/sources/UniXNU/scripts/probe-darwinboot-xnu.py" 2>/dev/null | head -25
  echo
  echo "== run_umi_qemu.py 是否支持 mockfs 根"
  grep -rn "mockfs" "$WS/tools/"*.py 2>/dev/null | head -20
  echo
  echo "== Kconfig 里 MOCKFS / NULL_ROOT 选项"
  grep -rn "MOCKFS\|NULL_ROOT" "$WS/sources/UniXNU" --include='Kconfig*' --include='*.kconfig' 2>/dev/null | head -10
  find "$WS/sources/UniXNU" -name 'Kconfig*' | head -5
} > "$OUT" 2>&1
echo WROTE
