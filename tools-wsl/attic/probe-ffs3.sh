#!/bin/bash
OUT=/mnt/e/Code/HackIos/out/probes/menu-ffs3.txt
: > "$OUT"
U=/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV
echo "== Guid.xref 头几行" >> "$OUT"
head -4 "$U/Guid.xref" >> "$OUT" 2>&1
echo "== Ffs 目录样本" >> "$OUT"
ls "$U/Ffs" | head -6 >> "$OUT" 2>&1
echo "== FFS -> 模块名（用 info.txt 里的 UI 名）" >> "$OUT"
python3 - <<'PY' >> "$OUT" 2>&1
import re, os
from pathlib import Path
U = Path("/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV")
txt = (U / "FVMAIN.Fv.txt").read_text().splitlines()
entries = [re.match(r"(0x[0-9a-fA-F]+)\s+([0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12})", l)
           for l in txt]
entries = [m.groups() for m in entries if m]
print("FFS entries in FVMAIN:", len(entries))
guids = {g.upper(): g for g in [e[1] for e in entries]}
names = {}
for d in sorted((U / "Ffs").iterdir()):
    guid = d.name.upper()
    if guid not in guids:
        continue
    ui = ""
    for sub in d.rglob("*.ui"):
        try:
            ui = sub.read_bytes().decode("utf-16-le").split("\0")[0]
        except Exception:
            ui = "?"
        break
    if not ui:
        for info in d.rglob("info.txt"):
            m = re.search(r'^UI\s+"?([^"\n]+)', info.read_text(errors="replace"), re.M)
            if m:
                ui = m.group(1).strip()
            break
    names[guid] = (ui or d.name, sum(f.stat().st_size for f in d.rglob("*") if f.is_file()))
missing = [g for g in guids.values() if g.upper() not in names]
for off, g in entries:
    n = names.get(g.upper())
    print(f"  {off} {g} {('%d B' % n[1]) if n else '':>12}  {n[0] if n else '(no Ffs dir)'}")
print("missing:", missing[:8])
PY
echo "== FDF 里 umi 自己的模块声明" >> "$OUT"
grep -nE "^ *(INF|FILE)" /home/unixnu/code/uefi-umi-b/Platforms/Xiaomi/umiPkg/umi.fdf 2>/dev/null | head -5 >> "$OUT"
echo "WROTE" >> "$OUT"
