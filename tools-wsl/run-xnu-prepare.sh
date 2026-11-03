#!/bin/bash
# #18：ram + darwinboot 档 prepare + 上屏补丁 + 装 UmiBootLog（只改构建树，不碰真机）
set -uo pipefail
WS=/home/unixnu/code/umi-work-pin
DST=/home/unixnu/code/uefi-umi-b
B=$WS/out/umi-local-binaries/uefi-binaries
cd "$WS" || exit 1

echo "== 1. 回滚 prepare 改过的 6 个文件（保留 Mu_Basecore 软链；不动 MuPatches 行尾）"
git -C "$DST" checkout -- \
  Platforms/Xiaomi/umiPkg/Include/APRIORI-order.json \
  Platforms/Xiaomi/umiPkg/Include/APRIORI.inc \
  Platforms/Xiaomi/umiPkg/Include/DXE.inc \
  Platforms/Xiaomi/umiPkg/umi.dsc \
  Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/ShimLoader.c \
  Silicon/Silicium/SiliciumPkg/Sec/Sec.c
git -C "$DST" status --porcelain | sed 's#^#  #'

echo "== 2. prepare（inherited + buttons + ram + darwinboot）"
python3 tools/prepare_umi_uefi.py --binaries "$B" \
  --display-profile inherited --input-profile buttons \
  --payload-profile ram --loader-profile darwinboot > /tmp/prep-xnu.log 2>&1
RC=$?
echo "  rc=$RC"
tail -20 /tmp/prep-xnu.log | sed 's#^#  | #'
[ $RC -ne 0 ] && exit 1

echo "== 3. 装回上屏补丁 + UmiBootLog"
python3 /mnt/e/Code/HackIos/tools-wsl/apply-memdiag-screen.py | sed 's#^#  #'
python3 /mnt/e/Code/HackIos/tools-wsl/install-bootlog.py | sed 's#^#  #'

echo "== 4. profile 记录"
python3 - <<'PY'
import json
d = json.load(open("/home/unixnu/code/umi-work-pin/out/umi/prepare.json"))
print("  profiles:", {k: d.get(k) for k in ("display_profile","input_profile","payload_profile","loader_profile")})
print("  loader_sha256 keys:", list(d.get("loader_sha256", {}).keys())[:6])
PY

echo "== 5. DarwinBoot 是否进了树"
grep -n "DarwinBoot" "$DST/Platforms/Xiaomi/umiPkg/umi.dsc" \
  "$DST/Platforms/Xiaomi/umiPkg/Include/DXE.inc" "$DST/Platforms/Xiaomi/umiPkg/Include/APRIORI.inc" | sed 's#^#  #'
ls "$WS/out/umi-menu-package/DarwinBootPkg/Driver/" 2>/dev/null | sed 's#^#  pkg: #'

echo "== 6. MuPatches 行尾仍为 CRLF（不能被改动）"
for p in Gic-Spurious Mac-Bash3 Dxe-Trace Display-Services-Trace; do
  f="$DST/Resources/MuPatches/$p.patch"
  cr=$(grep -c $'\r' "$f" 2>/dev/null)
  echo "  $p CR行=$cr"
done

echo "== 7. 树状态"
git -C "$DST" status --porcelain | sed 's#^#  #'
echo DONE
