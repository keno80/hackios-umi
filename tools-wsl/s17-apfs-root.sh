#!/bin/bash
# 取证：上游到底怎么造「真根」，这一步需不需要一台 macOS。
# 为什么现在要问：当前路线的四大缺口里 A（真根）是唯一被判定「必须外部输入」的一条，
# 而 E 步只证明了 WSL 没有 APFS 写路径——「有 APFS 写路径就能造根」这件事从来没被证据支持过。
# 要回答四件事：
#   1) 上游的根是 APFS 还是别的（alioth 与 umi 同 SoC SM8250，它的配方最值钱）；
#   2) 造根脚本跑在哪个 OS 上，调用了哪些只有 Darwin 才有的工具；
#   3) 根的内容来自哪里（IPSW 的哪些件）；
#   4) 有没有 Linux 也能跑的等价通路（比如直接 dd 一个现成容器 / mkapfs / ufs）。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s17-apfs-root.txt 2>&1
U=/home/unixnu/code/UniXNU-main

echo "== 1. 上游所有提到 apfs 的脚本/文档（文件名）=="
grep -rli apfs "$U/scripts" "$U/docs" 2>/dev/null | head -40

echo
echo "== 2. alioth.toml 里 root/filesystem 相关的 area 标题 =="
grep -n '^id = \|^status = ' "$U/docs/.vitepress/device-records/alioth.toml" 2>/dev/null | head -60

echo
echo "== 3. alioth.toml 里所有 apfs / root / seed / macos 命中的原句 =="
grep -niE 'apfs|mkapfs|data seed|root volume|macos|mac book|mac-mini|darwin' \
  "$U/docs/.vitepress/device-records/alioth.toml" 2>/dev/null | head -60

echo
echo "== 4. 造根脚本本体：看它调什么工具 =="
for f in $(grep -rliE 'apfs|userdata.*root|root.*image' "$U/scripts" 2>/dev/null | head -12); do
  echo "--- $f"
  grep -nE 'subprocess|check_call|diskutil|newfs_apfs|mkapfs|hdiutil|dd |losetup|mkfs|python3 |sys.platform|platform\.|darwin|Darwin' "$f" | head -18
done

echo
echo "== 5. 有没有 darwin 专属分支（同一脚本里 Linux 走哪条）=="
grep -rniE "sys\.platform|platform\.system|'darwin'|\"darwin\"" "$U/scripts" 2>/dev/null | head -30

echo
echo "== 6. 上游对「根从哪来」的正面描述（docs 里的 root 章节）=="
grep -rn -iE 'root (volume|filesystem)' "$U/docs" 2>/dev/null | head -25

echo "== done =="
