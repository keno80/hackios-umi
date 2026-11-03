#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
OUT=/mnt/e/Code/HackIos/out/storageabi-gen.txt
{
  echo "== build_umi_native_ufs.py 中 storage-abi 相关"
  grep -n "storage-abi\|abi" "$WS/tools/build_umi_native_ufs.py" | head -20
  echo
  echo "== 全 tools 里 storage-abi 出现的行"
  grep -rn "storage-abi" "$WS/tools" | head -30
  echo
  echo "== 有没有 prepare/build storage abi 的脚本"
  ls "$WS/tools" | grep -i "storage\|abi" 
  echo
  echo "== audit_umi_storage.py 全文头 40 行"
  head -40 "$WS/tools/audit_umi_storage.py"
  echo
  echo "== IOStorageFamily 源在不在（作者流程要求 out/umi-xnu/IOStorageFamily）"
  ls -d /home/unixnu/code/umi-work-pin/out/umi-xnu/IOStorageFamily 2>&1
  find /home/unixnu/code -maxdepth 5 -type d -name 'IOStorageFamily*' 2>/dev/null | head
  echo
  echo "== source-lock / feeds 清单里有没有 IOStorageFamily"
  grep -rn "IOStorageFamily" /home/unixnu/code/UniXNU-pin --include='*.json' --include='*.toml' --include='*.md' --include='*.py' --include='*.sh' 2>/dev/null | head -20
} > "$OUT" 2>&1
echo WROTE
