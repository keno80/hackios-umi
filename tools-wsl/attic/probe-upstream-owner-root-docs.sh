#!/bin/bash
# U 步之三备料取证：上游 own-owner-root 这条链的文档与脚本对 volume-info / host 库到底怎么说。
exec > /mnt/e/Code/HackIos/out/probes/u96-upstream-owner-root-docs.txt 2>&1
set -u
M=/home/unixnu/code/UniXNU-main

echo "== A. 谁产 *-volume-info.json（全盘找写者） =="
grep -rn "volume-info" $M --include=*.py --include=*.sh --include=*.md --include=*.toml 2>/dev/null | head -30
echo "  -- diskutil 出现处 --"
grep -rn "diskutil" $M --include=*.py --include=*.md --include=*.toml 2>/dev/null | head -20

echo
echo "== B. build-owner-os-policy.py 全文 =="
cat $M/scripts/build-owner-os-policy.py 2>&1

echo
echo "== C. build-verified-root-probe.py 全文 =="
cat $M/scripts/build-verified-root-probe.py 2>&1

echo
echo "== D. device-records 里 owner-root / verified-root / volume-info 的机型教训 =="
grep -rn -i "owner.root\|verified.root\|root.policy\|owner_root" $M/docs/.vitepress/device-records/*.toml 2>/dev/null | head -40

echo
echo "== E. umi 机型记录（本机的硬教训） =="
sed -n '1,200p' $M/docs/.vitepress/device-records/umi.toml 2>&1 || ls $M/docs/.vitepress/device-records/ 2>&1 | head -40

echo
echo "== F. 上游 git 里有没有 Linux 侧跑过 root-policy 的痕迹 =="
grep -rln "linux" $M/scripts/*owner* $M/scripts/*verified* 2>/dev/null
echo "  -- scripts/linux/xcrun 是否会吞掉 -dynamiclib（我们的替代点） --"
cat $M/scripts/linux/xcrun 2>&1
echo done
