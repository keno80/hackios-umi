#!/bin/bash
# 在 pin 树/设备仓里找作者关于挂根这一步的记录与 root-match-volume-uuid 的用法
{
  cd /home/unixnu/code/umi-work-pin || exit 1
  echo "== grep 04769D26"
  grep -rn "04769D26\|04769d26" --include="*.py" --include="*.md" --include="*.toml" --include="*.json" . 2>/dev/null | grep -v "^./out/" | head -20
  echo "== grep IOFindBSDRoot / root device 记录"
  grep -rln "IOFindBSDRoot" . 2>/dev/null | grep -v "^./out/" | head -10
  echo "== bringup 下的 umi 记录"
  ls bringup 2>/dev/null | head -20
  grep -rn "root" bringup/tools/audit_umi_qemu.py 2>/dev/null | head -30
  echo "== devices/umi 文档"
  ls -l devices/umi 2>/dev/null | head -20
  find devices/umi -maxdepth 2 -name "*.md" 2>/dev/null | head -10
  echo "== run_umi_qemu.py 里 root-volume 的注释"
  grep -n "root" tools/run_umi_qemu.py | head -40
} > /mnt/e/Code/HackIos/out/probes/root-docs.txt 2>&1
echo WROTE
