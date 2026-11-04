#!/bin/bash
# 重放 kit 补丁并后台启动内核增量编译（输出落 out/kit2-build.txt）
set -u
OUT=/mnt/e/Code/HackIos/out
cd /mnt/e/Code/HackIos || exit 1
{
  echo "== regenerate patch $(date -Is)"
  python3 tools-wsl/make-crypto-patch.py
  echo "rc=$?"
  echo "== tail of patched register_crypto.c"
  tail -3 out/umi-xnu-dummy 2>/dev/null
  W=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work
  grep -c 'ccaes_cbc_encrypt' "$W/libkern/crypto/register_crypto.c"
  echo "== launch build"
  bash tools-wsl/run-kernel-screen.sh
} > "$OUT/kit2-build.txt" 2>&1
echo done
