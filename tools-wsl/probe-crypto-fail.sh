#!/bin/bash
# 抓 crypto kit 重编失败的第一条真实原因（构建已退出，日志稳定）
set -u
L=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/logs/20261103T130825322842Z/kernel.log
O=/mnt/e/Code/HackIos/out/probes/crypto-build-fail.txt
{
  echo "== log size =="
  ls -l "$L"
  echo "== first error-ish lines (pure grep, no interleaving) =="
  grep -naE "(error|Error) [:(]|fatal error|undefined symbol|Undefined symbols|ld: |cannot|No rule to make target|\*\*\*" "$L" | head -60
  echo "== register_crypto mentions =="
  grep -na "register_crypto" "$L" | head -30
  echo "== umi_crypto_kit mentions =="
  grep -na "umi_crypto_kit" "$L" | head -30
  echo "== startup.h / __startup_func mentions =="
  grep -naE "__startup_func|kern/startup\.h|STARTUP\(EARLY_BOOT" "$L" | head -30
  echo "== last 60 lines =="
  tail -60 "$L"
} > "$O" 2>&1
echo done
