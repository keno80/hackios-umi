#!/bin/bash
# 一次性审计：umi 的 17 个补丁对着 main 的上游系列，哪些能打上、哪些冲突
set -u
W=/home/unixnu/code/UniXNU-main/out/umi/tree
work=$W/.cache/xnu-work
echo "== 重建干净工作树 =="
rm -rf "$work"
git clone --shared "$W/refer/xnu" "$work" > /dev/null 2>&1
echo "HEAD=$(git -C "$work" rev-parse --short HEAD)"
echo "== 先打 main 自己的系列 =="
n=0
for p in "$W"/patches/xnu/*.patch "$W"/kits/XnuPrelink/patches/*.patch; do
  [ -f "$p" ] || continue
  if git -C "$work" apply --reverse --check "$p" >/dev/null 2>&1; then continue; fi
  if git -C "$work" apply --check "$p" >/dev/null 2>&1; then
    git -C "$work" apply "$p"; n=$((n+1))
  else
    echo "main 系列冲突：$(basename "$p")"
  fi
done
echo "main 系列应用数=$n"
echo "== 逐个 umi 补丁 =="
ok=0; bad=0
for p in "$W"/patches/umi-xnu/*.patch; do
  b=$(basename "$p")
  if git -C "$work" apply --reverse --check "$p" >/dev/null 2>&1; then
    echo "已包含 $b"; ok=$((ok+1)); continue
  fi
  if git -C "$work" apply --check "$p" >/dev/null 2>&1; then
    git -C "$work" apply "$p"; echo "OK       $b"; ok=$((ok+1))
  else
    first=$(git -C "$work" apply --check "$p" 2>&1 | head -1)
    echo "冲突     $b :: $first"
    bad=$((bad+1))
  fi
done
echo "== 汇总 OK=$ok 冲突=$bad =="
