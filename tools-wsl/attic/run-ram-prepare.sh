#!/bin/bash
# #16：把 payload profile 换成 ram（内存诊断档），只改构建树，不碰真机
set -uo pipefail
WS=/home/unixnu/code/umi-work-pin
DST=/home/unixnu/code/uefi-umi-b
B=$WS/out/umi-local-binaries/uefi-binaries
cd "$WS" || exit 1

echo "== 1. 只回滚 prepare 改过的 6 个文件（保留 Mu_Basecore 软链）"
git -C "$DST" checkout -- \
  Platforms/Xiaomi/umiPkg/Include/APRIORI-order.json \
  Platforms/Xiaomi/umiPkg/Include/APRIORI.inc \
  Platforms/Xiaomi/umiPkg/Include/DXE.inc \
  Platforms/Xiaomi/umiPkg/umi.dsc \
  Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/ShimLoader.c \
  Silicon/Silicium/SiliciumPkg/Sec/Sec.c
git -C "$DST" status --porcelain | sed 's#^#  #'

echo "== 2. prepare（inherited + buttons + ram + loader none）"
python3 tools/prepare_umi_uefi.py --binaries "$B" \
  --display-profile inherited --input-profile buttons \
  --payload-profile ram --loader-profile none > /tmp/prep-ram.log 2>&1
echo "  rc=$?"
tail -15 /tmp/prep-ram.log | sed 's#^#  | #'

echo "== 3. 新树状态"
git -C "$DST" status --porcelain | sed 's#^#  #'
python3 - <<'PY'
import json
d = json.load(open("/home/unixnu/code/umi-work-pin/out/umi/prepare.json"))
print("  profiles:", {k: d[k] for k in ("display_profile","input_profile","payload_profile","loader_profile")})
PY

echo "== 4. ram 档到底往树里塞了什么"
git -C "$DST" diff --stat -- Platforms/Xiaomi/umiPkg/Include/DXE.inc \
  Platforms/Xiaomi/umiPkg/Include/APRIORI.inc Platforms/Xiaomi/umiPkg/umi.dsc | sed 's#^#  #'
git -C "$DST" diff -- Platforms/Xiaomi/umiPkg/Include/DXE.inc \
  Platforms/Xiaomi/umiPkg/Include/APRIORI.inc Platforms/Xiaomi/umiPkg/umi.dsc | grep -E '^[+-]' | grep -v '^[+-][+-]' | sed 's#^#  #'

echo "== 5. MuPatches 行尾规范化 + 4 补丁 pre-check"
for f in "$DST"/Resources/MuPatches/*.patch; do
  if grep -q $'\r' "$f"; then tr -d '\r' < "$f" > "$f.lf" && mv "$f.lf" "$f"; echo "  LF 化 $(basename "$f")"; fi
done
for p in Gic-Spurious Mac-Bash3 Dxe-Trace Display-Services-Trace; do
  if git -C /home/unixnu/code/Mu_Basecore apply --check "$DST/Resources/MuPatches/$p.patch" 2>/dev/null; then
    echo "  OK    $p"
  elif git -C /home/unixnu/code/Mu_Basecore apply --reverse --check "$DST/Resources/MuPatches/$p.patch" 2>/dev/null; then
    echo "  ALREADY $p"
  else
    echo "  FAIL  $p"
  fi
done
echo DONE
