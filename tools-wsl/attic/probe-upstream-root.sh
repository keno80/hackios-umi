#!/bin/bash
set -u
cd /e/Code/HackIos || exit 1
O=out/upstream-root-docs.txt
: > "$O"
{
  echo "== fetch upstream main（只进 FETCH_HEAD，不动本地 pin）=="
  git -C UniXNU-main fetch --quiet origin main 2>&1 | tail -3
  echo "fetch rc=$?"
  git -C UniXNU-main log -1 --format='%h %ad %s' --date=short FETCH_HEAD 2>&1
  echo ""
  echo "== 上游文档里提到 root/APFS/restore 的文件 =="
  git -C UniXNU-main grep -l -i -E 'mount root|root device|apfs|restore image|bootstage|kextcollection' FETCH_HEAD -- 'docs' 2>&1 | head -25
  echo ""
  echo "== 命中行（含上下文标题）=="
  git -C UniXNU-main grep -n -i -E 'failed to mount root|mount_root|root=device|apfs|packed' FETCH_HEAD -- 'docs' 2>&1 | head -40
} >> "$O" 2>&1
echo done
