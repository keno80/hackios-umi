#!/bin/bash
# 取证：「打 APFS 真根」这件事到底需不需要一台 macOS。
# 触发点：用户给了一台 VMware 虚拟机配置（8G/4vCPU/500G），问能不能拿来打真根。
# 在回答之前必须先分清两件事，否则会把手机时间花在错误的依赖上：
#   1) 上游同 SoC（alioth = SM8250）的真根是 APFS 还是 UFS？摘要里写的是 "UFS root with launchd"；
#   2) 造根/取根的代码路径里，哪些是 Darwin 独占，哪些已经有非 Darwin 分支（E 步只证明了「读 DMG 有 Linux 分支」）。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s18-root-needs-mac.txt 2>&1
U=/home/unixnu/code/UniXNU-main
D=$U/docs/.vitepress/device-records

echo "== 1. alioth 的 storage area 全文（180-218 行）=="
sed -n '178,220p' "$D/alioth.toml"

echo
echo "== 2. 全库 device-records 里 UFS 根 vs APFS 根的完成判据 =="
grep -rn -iE 'mounts? (read-only )?from UFS|root volume.*UFS|UFS root' "$D" | head -20
echo "--- APFS 作为根的："
grep -rn -iE 'root volume.*apfs|apfs.*root volume|mounts? .*apfs' "$D" | head -20

echo
echo "== 3. userdata.py 的非 Darwin 分支到底做了什么（读 vs 写）=="
sed -n '1,120p' "$U/scripts/unixnu/userdata.py"

echo
echo "== 4. ipsw.py 里两处 platform 判断的上下文 =="
sed -n '185,260p' "$U/scripts/unixnu/ipsw.py"

echo
echo "== 5. 有没有「造/写 APFS」的脚本，以及它是否只在 Darwin 能跑 =="
for f in "$U/scripts/prepare-owner-data-fixture.py" "$U/scripts/make-data-seed.py" "$U/scripts/seed-data-grow.py" "$U/scripts/prepare-offline-data.py"; do
  echo "--- $f"
  [ -f "$f" ] || { echo "(不存在)"; continue; }
  grep -nE 'hdiutil|diskutil|APFS|apfs|mkapfs|platform\.system|Darwin|dd |mcopy|losetup' "$f" | head -14
done

echo
echo "== 6. 上游文档里对「根从 IPSW 到分区」的写入方式 =="
grep -rn -iE 'restore.*userdata|write.*OS volume|flash.*root|root.*partition' "$U/docs" 2>/dev/null | head -20

echo "== done =="
