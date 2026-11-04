#!/bin/bash
# 回答「距离启动 OS 还有多远」要用最硬的尺子：上游 UniXNU 自己现在到哪儿了。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s6-upstream-status.txt 2>&1
U=/home/unixnu/code/UniXNU-main

echo "== 1. device-records 目录在哪 =="
find "$U" -maxdepth 6 -type d -name 'device-records' 2>/dev/null | head -3
D=$(find "$U" -maxdepth 6 -type d -name 'device-records' 2>/dev/null | head -1)
echo "D=$D"

echo
echo "== 2. 机型清单 =="
ls "$D" 2>/dev/null | head -30

echo
echo "== 3. 每台机器状态行（找 wallpaper/SpringBoard/userland/EL0/launchd 这类水位词）=="
grep -rn -i 'status\|wallpaper\|springboard\|userland\|boot progress\|milestone' "$D"/*.toml 2>/dev/null | head -40

echo
echo "== 4. README 里怎么说进度 =="
grep -n -i -A6 'status\|progress\|what works\|not yet\|roadmap' "$U/README.md" 2>/dev/null | head -60

echo
echo "== 5. 有没有任何机型声称跑起 iOS 用户态（真件）=="
grep -rn -i 'dyld_shared_cache\|launchd\|iOS 1[5-8]\|iPadOS' "$D"/*.toml "$U/README.md" 2>/dev/null | head -30

echo
echo "== 6. 本仓库目标定义（对照用）=="
grep -rn -i 'goal\|目标' "$U/README.md" 2>/dev/null | head -10
echo "== done $(date -u +%FT%TZ)"
