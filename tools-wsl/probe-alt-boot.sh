#!/bin/bash
OUT=/mnt/e/Code/HackIos/out/probes/alt-boot-route.txt
: > "$OUT"
WS=/home/unixnu/code/umi-work-pin

echo "== 1. 仓里关于 fastboot boot / flash boot 的说法" >> "$OUT"
grep -rn "fastboot boot\|flash boot\|Unrecognized\|boot_a\|slot" "$WS/devices/umi" --include="*.md" 2>/dev/null | head -25 >> "$OUT"
echo "-- 上游文档" >> "$OUT"
grep -rn "fastboot boot" "$WS/sources/UniXNU/docs/zh" 2>/dev/null | head -8 >> "$OUT"

echo "== 2. 本机分区里 boot 是不是分槽" >> "$OUT"
grep -iE "boot" /mnt/e/Code/HackIos/out/phone3/partitions.txt 2>/dev/null | head -12 >> "$OUT"

echo "== 3. 原始 boot.img 备份完整性（sha 对 manifest）" >> "$OUT"
python3 - <<'PY' >> "$OUT" 2>&1
import json, hashlib
from pathlib import Path
d = Path("/mnt/e/Code/HackIos/out/phone3")
m = json.loads((d / "manifest.json").read_text())
arts = m.get("artifacts", {})
for name in ("boot.img", "dtbo.img", "running.dtb"):
    meta = arts.get(name) or arts.get(name.replace(".img", "")) or {}
    f = d / name
    if not f.is_file():
        print(f"{name}: 文件缺失"); continue
    h = hashlib.sha256(f.read_bytes()).hexdigest()
    exp = meta.get("sha256"); size = meta.get("bytes", meta.get("size"))
    print(f"{name}: 实测 {f.stat().st_size:,} B sha {h[:16]}…  manifest 期望 {str(exp)[:16]}…/{size}  {'一致' if exp==h else ('不一致' if exp else 'manifest 无 sha')}")
print("artifacts 键:", list(arts)[:14])
PY
echo "== 4. 采集时 device_writes 记录（应为空）" >> "$OUT"
python3 -c "
import json;m=json.load(open('/mnt/e/Code/HackIos/out/phone3/manifest.json'));print('device_writes:',m.get('device_writes'))" >> "$OUT" 2>&1
echo WROTE >> "$OUT"
