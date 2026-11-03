#!/bin/bash
# 把 WSL 里的 UniXNU-umi 工作树按 index(LF) 重建；先看有没有本地改动，避免覆盖
set -u
R=/home/unixnu/code/UniXNU-umi
real=$(readlink -f "$R")
echo "真实路径=$real"
case "$real" in
  /mnt/*) echo "指向 Windows 挂载，拒绝改写，停手"; exit 1;;
esac
[ -d "$real/.git" ] || { echo "不是独立 git 仓，停手"; exit 1; }
echo "== 重建前 status（前 20 行） =="
git -C "$R" status --porcelain | head -20
echo "脏文件数=$(git -C "$R" status --porcelain | wc -l)"
echo "未跟踪数=$(git -C "$R" status --porcelain --untracked-files=no | wc -l)"
echo "忽略行尾符后的真实差异=$(git -C "$R" diff --ignore-cr-at-eol --stat | wc -l) 行"
if [ "$(git -C "$R" diff --ignore-cr-at-eol --stat | wc -l)" != "0" ]; then
  echo "存在真实内容改动，先停手，不重建"
  git -C "$R" diff --ignore-cr-at-eol --stat | head -10
  exit 1
fi
echo "== 从 index 重建工作树 =="
git -C "$R" checkout-index -f -a
echo "exit=$?"
echo "CRLF 补丁数=$(for f in "$R"/patches/umi-xnu/*.patch; do grep -lc $'\r' "$f" 2>/dev/null; done | wc -l)"
echo "重建后脏文件数=$(git -C "$R" status --porcelain | wc -l)"
echo "HEAD=$(git -C "$R" rev-parse HEAD)"
echo "== 树里的符号链接指向 =="
ls -l /home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/patches/ 2>/dev/null | head -8
