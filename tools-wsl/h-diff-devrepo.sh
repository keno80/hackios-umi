#!/bin/bash
# 对比 Windows 侧设备仓与 ext4 构建输入侧的差异，决定同步范围
set -u
OUT=/mnt/e/Code/HackIos/out/probes/h-devrepo-diff.txt
W=/mnt/e/Code/HackIos/UniXNU-umi
S=/home/unixnu/code/UniXNU-umi
exec >"$OUT" 2>&1

echo "== ext4 侧对我改的这两个文件有没有本地改动 =="
git -C "$S" diff --stat -- patches/umi-xnu/early-entry-trace.patch scripts/umi-early-trace.inc 2>&1 | tail -3
echo "rc=$?"

echo
echo "== 两边 patches/umi-xnu 目录差异 =="
diff -rq "$W/patches/umi-xnu" "$S/patches/umi-xnu" 2>&1 | head -20

echo
echo "== 两边 scripts 目录差异 =="
diff -rq "$W/scripts" "$S/scripts" 2>&1 | head -20

echo
echo "== ext4 侧 317 个 dirty 到底是什么改动（抽样） =="
git -C "$S" diff --stat 2>&1 | tail -3
git -C "$S" diff -- board.toml 2>&1 | head -12
