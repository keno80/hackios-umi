#!/bin/bash
# T 步前置取证：要把「一个真 Apple 的 EL0 件」塞进 mockfs 假根 exec，先得有那个件。
# 三个问题，一次问清：
#   1) 本机磁盘上到底有没有 IPSW 成员/DMG 的本地缓存（还是每次都要联网取）；
#   2) Linux 侧能不能把 APFS 卷里的单个文件读出来（apfsprogs 只有 mkapfs/apfsck/fsapfsinfo 的话就不够）；
#   3) 上游自己有没有 python/C 的 APFS 读实现，以及它拿真件时走的是哪条路。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s24-real-apple-file.txt 2>&1
U=/home/unixnu/code/UniXNU-main
W=/home/unixnu/code/umi-work-pin

echo "== 1. 本机所有 ipsw/dmg/apfs 类缓存（含大小，前 40 条）=="
find "$U" "$W" -maxdepth 6 \( -iname '*.ipsw' -o -iname '*.dmg' -o -iname '*root.img' -o -iname '*.apfs' -o -ipath '*ipsw*' -a -type f \) \
  -printf '%10s %p\n' 2>/dev/null | sort -rn | head -40

echo
echo "== 2. out/ipsw 缓存目录到底有什么 =="
for d in "$U"/out/ipsw "$W"/out/*/ipsw "$W"/out/umi-xnu/umi/tree/out/ipsw; do
  [ -d "$d" ] && { echo "--- $d"; ls -la "$d" | head -20; }
done

echo
echo "== 3. apfsprogs 提供哪些可执行（能不能导出文件）=="
dpkg -L apfsprogs 2>/dev/null | grep -E 'bin/' || echo "  apfsprogs 未装或 dpkg 无记录"
for b in mkapfs apfsck fsapfsinfo apfs-dump apfs-fuse; do command -v "$b" 2>/dev/null; done

echo
echo "== 4. 上游有没有自己的 APFS 读实现（python 或 C）=="
grep -rln -i 'apfs' "$U/scripts" 2>/dev/null | head -20
echo "--- 其中像「解析 APFS 并取文件」的："
grep -rn -i 'NXSB\|apfs.*super.*block\|class Apfs\|def.*apfs' "$U/scripts" 2>/dev/null | head -20

echo
echo "== 5. 上游取「真件」的现成通路：board.toml 的 userdata windows 与 payload 里的文件来源 =="
grep -rn -A6 '\[\[userdata.windows\]\]\|\[userdata\]' "$W"/out/umi-xnu/umi/boards/*.toml 2>/dev/null | head -40
echo "--- 上游脚本里有没有直接从 IPSW 抽单个文件的（cryptex/extract 之类）："
grep -rln -i 'cryptex\|ExtractIpsw\|extract_file\|member_path' "$U/scripts" 2>/dev/null | head -10

echo
echo "== 6. 我们自己的 userdata-root.img 在哪、多大、里面窗口是什么 =="
find "$W" -name 'userdata-root.img' -printf '%10s %TY-%Tm-%Td %p\n' 2>/dev/null | head
