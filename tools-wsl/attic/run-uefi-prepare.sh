#!/bin/bash
# 生成本地 umi 菜单包（inherited display + buttons），不碰真机、不导入 vendor 固件
set -uo pipefail
WS=/home/unixnu/code/umi-work-pin
DST=/home/unixnu/code/uefi-umi-b
B=$WS/out/umi-local-binaries/uefi-binaries
cd "$WS" || exit 1

echo "== 1. 给 prepare_umi_uefi.py 加 empty_vendor 分支"
cp -n /mnt/e/Code/HackIos/tools-wsl/port-empty-vendor.py /tmp/port-empty-vendor.py
[ -f tools/prepare_umi_uefi.py.macos-original ] || cp tools/prepare_umi_uefi.py tools/prepare_umi_uefi.py.macos-original
python3 /tmp/port-empty-vendor.py || exit 1

echo "== 2. 空 vendor 清单（如实标注）"
mkdir -p "$B"
python3 - "$B/manifest.json" <<'PY'
import json, sys
json.dump({"device": "umi", "empty_vendor": True,
           "note": "本机未做 XBL vendor 固件导入；inherited display profile 剔除全部 Binaries/umi 条目",
           "modules": [], "raw_files": []}, open(sys.argv[1], "w"), indent=2, ensure_ascii=False)
print("  " + sys.argv[1])
PY

echo "== 3. 源 pin 核对"
for p in sources/UniXNU sources/uefi-umi sources/uefi-umi/Mu_Basecore; do
  printf "  %-32s %s\n" "$p" "$(git -C $p rev-parse HEAD)"
done

echo "== 4. 跑 prepare (inherited + buttons)"
python3 tools/prepare_umi_uefi.py --binaries "$B" --display-profile inherited --input-profile buttons > /tmp/prep.log 2>&1
echo "  rc=$?"
tail -12 /tmp/prep.log | sed 's#^#  | #'

echo "== 5. 规范化 MuPatches 行尾（overlay 覆盖后可能有 CRLF）"
for f in "$DST"/Resources/MuPatches/*.patch; do
  if grep -q $'\r' "$f"; then tr -d '\r' < "$f" > "$f.lf" && mv "$f.lf" "$f"; echo "  LF 化 $(basename "$f")"; fi
done

echo "== 6. 4 个 Mu 补丁 pre-check（在长构建之前）"
for p in Gic-Spurious Mac-Bash3 Dxe-Trace Display-Services-Trace; do
  if git -C "$DST/Mu_Basecore" apply --check "$DST/Resources/MuPatches/$p.patch" 2>/dev/null; then
    echo "  OK    $p"
  elif git -C "$DST/Mu_Basecore" apply --reverse --check "$DST/Resources/MuPatches/$p.patch" 2>/dev/null; then
    echo "  ALREADY-APPLIED $p"
  else
    echo "  FAIL  $p"; git -C "$DST/Mu_Basecore" apply --check "$DST/Resources/MuPatches/$p.patch" 2>&1 | head -3
  fi
done

echo "== 7. 结果核对"
printf "  prepare.json: %s\n" "$(ls -l "$WS/out/umi/prepare.json" 2>/dev/null | awk '{print $5" bytes"}')"
grep -c "Binaries/umi" "$DST/Platforms/Xiaomi/umiPkg/Include/DXE.inc" "$DST/Platforms/Xiaomi/umiPkg/Include/APRIORI.inc" 2>/dev/null | sed 's#^#  #'
tail -3 "$DST/Platforms/Xiaomi/umiPkg/umi.dsc" | sed 's#^#  dsc: #'
printf "  菜单包文件数=%s\n" "$(find "$WS/out/umi-menu-package" -type f 2>/dev/null | wc -l)"
python3 - <<PY
import json
d = json.load(open("$WS/out/umi/prepare.json"))
print("  profiles:", {k: d[k] for k in ("display_profile", "input_profile", "payload_profile", "loader_profile")})
print("  import_manifest:", d["import_manifest"])
print("  overlay 覆盖文件数:", len(d["overlay_sha256"]))
PY
echo DONE
