#!/bin/bash
OUT=/mnt/e/Code/HackIos/out/menu-ffs4.txt
python3 - <<'PY' > "$OUT" 2>&1
import re
from pathlib import Path
U = Path("/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV")
xref = {}
for line in (U / "Guid.xref").read_text().splitlines():
    m = re.match(r"\s*([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})\s+(.*)", line)
    if m:
        xref[m.group(1).upper()] = m.group(2).strip()
print("Guid.xref 条目:", len(xref))
entries = []
for l in (U / "FVMAIN.Fv.txt").read_text().splitlines():
    m = re.match(r"(0x[0-9a-f]+)\s+([0-9A-Fa-f-]{36})", l)
    if m:
        entries.append((int(m.group(1), 16), m.group(2).upper()))
print("FVMAIN 内 FFS 文件数:", len(entries), " 总容量 0x1e3000, 已用 0x1e2bd8 (余 1064 B)")
sizes = {}
for d in (U / "Ffs").iterdir():
    if d.is_dir():
        g = d.name[:36].upper()
        sizes[g] = sum(f.stat().st_size for f in d.rglob("*") if f.is_file())
seen = set()
for off, g in entries:
    nm = xref.get(g, "?")
    if nm in seen:
        nm += " (dup)"
    seen.add(nm)
    print(f"  {off:#09x}  {nm:34s} {sizes.get(g,0):>10,d} B")
print("-- 未解析 GUID:", [g for _, g in entries if g not in xref])
KEY = ("UmiInheritedFb", "UmiButtons", "UniXNU", "BootManagerMenu", "DtPlatform", "RamManager", "BdsDxe", "ConSplitter", "GraphicsConsole", "MsBootPolicy")
print("-- 关键模块在场:", {k: any(k in v for v in seen) for k in KEY})
PY
echo WROTE >> "$OUT"
