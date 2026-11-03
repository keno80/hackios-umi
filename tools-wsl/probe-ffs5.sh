#!/bin/bash
OUT=/mnt/e/Code/HackIos/out/menu-ffs5.txt
python3 - <<'PY' > "$OUT" 2>&1
import re
from pathlib import Path
U = Path("/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV")
xref = {}
for line in (U / "Guid.xref").read_text().splitlines():
    m = re.match(r"\s*([0-9A-Fa-f-]{36})\s+(.*)", line)
    if m:
        xref[m.group(1).upper()] = m.group(2).strip()
txt = (U / "FVMAIN.Fv.txt").read_text() + (U / "FVMAIN_COMPACT.Fv.txt").read_text()
guids = [g.upper() for g in re.findall(r"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}", txt)]
seen, out = set(), []
for g in guids:
    if g in xref and xref[g] not in seen:
        seen.add(xref[g]); out.append(xref[g])
print("FV 内解析出的模块数:", len(out))
for n in sorted(out):
    print("  ", n)
KEY = ["UmiInheritedFbDxe", "UmiButtonsDxe", "UniXNU", "UniXNUDxe", "BootManagerMenuApp",
       "DtPlatformDxe", "RamManagerDxe", "BdsDxe", "GraphicsConsoleDxe", "DxeCore", "Sec",
       "DisplayReEnablerDxe", "EmmcDxe", "SdDxe", "UFPLoader"]
print("关键模块:", {k: (k in seen) for k in KEY})
PY
echo WROTE >> "$OUT"
