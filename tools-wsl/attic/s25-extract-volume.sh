#!/bin/bash
# 接 s24：本机已经有 IPSW 的两个 DMG（21H461，5.16G + 3.30G）和 9.38G 的 userdata-root.img，
# 而且上游有个 scripts/extract-target-volume.py——名字正好是「从目标卷里抽文件」。
# 本文件只问一件事：这个脚本在 Linux 上能不能跑、抽出来的是什么粒度的东西。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s25-extract-volume.txt 2>&1
U=/home/unixnu/code/UniXNU-main

echo "== 1. extract-target-volume.py 全文 =="
cat -n "$U/scripts/extract-target-volume.py"

echo
echo "== 2. 它依赖什么（import 与 subprocess 调的外部工具）=="
grep -nE '^import |^from |subprocess|tool\(' "$U/scripts/extract-target-volume.py" | head -30

echo
echo "== 3. 谁调用它（上游怎么用的，参数从哪来）=="
grep -rn 'extract-target-volume' "$U/scripts" "$U/docs" 2>/dev/null | grep -v '\.pyc' | head -20

echo
echo "== 4. 上游有没有 APFS 的 python 读实现（哪怕只读 superblock）=="
grep -rln 'NXSB' "$U/scripts/unixnu" 2>/dev/null
grep -rn 'def .*apfs\|class .*[Aa]pfs' "$U/scripts" 2>/dev/null | grep -v pyc | head -10

echo
echo "== 5. apisfs / apfs 相关 pip 包是否已装 =="
python3 -c 'import apisfs, sys; print("apisfs", apisfs.__file__)' 2>&1 | head -3
pip3 list 2>/dev/null | grep -i apfs || echo "  无 apfs pip 包"

echo
echo "== 6. 本地两个 DMG 的身份（json 侧车）=="
for f in /home/unixnu/code/umi-work-pin/out/umi-xnu/ipsw/21H461/*.json; do echo "--- $f"; cat "$f"; done
