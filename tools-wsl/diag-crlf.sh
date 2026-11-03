#!/bin/bash
# 查 autocrlf 来源与受影响文件，并把设备仓工作树按 LF 重建（不碰未跟踪文件）
set -u
for r in /home/unixnu/code/UniXNU-umi /home/unixnu/code/UniXNU-pin /home/unixnu/code/UniXNU-main /home/unixnu/code/UniXNU-sheng; do
  echo "== $r"
  echo "autocrlf=$(git -C "$r" config --get core.autocrlf)"
  echo "eol 样例: $(git -C "$r" ls-files --eol patches/umi-xnu/early-entry-trace.patch bringup/tools/build_umi_xnu.py 2>/dev/null | head -2 | tr '\n' ' ')"
  echo "CRLF 补丁数=$(for f in "$r"/patches/umi-xnu/*.patch; do grep -lc $'\r' "$f" 2>/dev/null; done | wc -l)"
done
echo "== 全局配置 =="
git config --global --list 2>/dev/null | head -10
echo "== /root/.gitconfig 存在？ =="
ls -l /root/.gitconfig 2>/dev/null || echo "无"
