#!/bin/bash
set -uo pipefail
W=/home/unixnu/code/umi-work-pin
D=/home/unixnu/code/uefi-umi-b
cd "$W" || exit 1
echo "== 1. FD 用量（FD 必须正好 0x300000）"
python3 - <<'PY'
import pathlib
fd = pathlib.Path("/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd")
print(f"  FD bytes={fd.stat().st_size} (0x{fd.stat().st_size:x})")
PY
echo "== 2. DebugLib 走向（DEBUG 上屏还是串口）"
grep -rn "DebugLib" "$D/Platforms/Xiaomi/umiPkg/Include/"*.inc 2>/dev/null | head -5 | sed 's#^#  #'
grep -rn -E "^  DebugLib" "$D/Platforms/Xiaomi/umiPkg/umi.dsc" "$D/Silicon/Silicium/SiliciumPkg"/*.dsc* 2>/dev/null | head -6 | sed 's#^#  #'
find "$D/Silicon" -maxdepth 6 -type d -iname "*DebugLib*" | sed 's#^#  #'
echo "== 3. 造 8 MiB 内存诊断 FAT"
python3 tools/make_umi_payload.py --diagnostic memory > /tmp/mkpay.log 2>&1
echo "  rc=$?"; tail -25 /tmp/mkpay.log | sed 's#^#  | #'
echo "== 4. FAT 内容自检"
ls -l out/umi/payload/umi-ram-fat.img 2>/dev/null | sed 's#^#  #'
mdir -i out/umi/payload/umi-ram-fat.img ::/EFI/UniXNU/Payloads 2>/dev/null | sed 's#^#  #' || mls -i out/umi/payload/umi-ram-fat.img -R :: 2>/dev/null | head -10 | sed 's#^#  #'
