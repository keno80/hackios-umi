#!/bin/bash
# alioth 与 umi 同一颗 SM8250。它已经到锁屏——把它的组件清单拉出来，就是 umi 到锁屏的缺口表。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s8-alioth-components.txt 2>&1
D=/home/unixnu/code/UniXNU-main/docs/.vitepress/device-records

echo "== 1. alioth.toml 的 components 段 =="
grep -n -A60 '\[\[components\]\]\|^components' "$D/alioth.toml" | head -90

echo
echo "== 2. 全文里所有 name = 的组件名 =="
grep -n 'name = ' "$D/alioth.toml" | head -40

echo
echo "== 3. 本机 umi 已具备的对应物（看我们仓库里有哪些 sheng 模块）=="
ls /home/unixnu/code/UniXNU-sheng 2>/dev/null | head -40

echo
echo "== 4. alioth 的 os_profile 与 root 方案关键词 =="
grep -n -i 'os_profile\|UFS\|APFS\|VerifiedRoot\|Data\|prelink\|trustcache' "$D/alioth.toml" | head -30

echo
echo "== 5. alioth 记录里的「还差什么」段（未归因/阻塞项）=="
grep -n -i -A3 'blocking\|not yet\|missing\|TODO\|no Wi-Fi' "$D/alioth.toml" | head -40
echo "== done $(date -u +%FT%TZ)"
