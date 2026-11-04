#!/bin/bash
OUT=/mnt/e/Code/HackIos/out/probes/slot-check.txt
: > "$OUT"
D=/mnt/e/Code/HackIos/out/phone3
echo "== 1. by-name 分区里 boot / recovery 的槽位形态" >> "$OUT"
grep -iE "boot|recovery" "$D/partition-links.txt" 2>/dev/null | head -20 >> "$OUT"
echo "-- partitions.txt 头 8 行（看格式）" >> "$OUT"
head -8 "$D/partitions.txt" >> "$OUT" 2>&1

echo "== 2. 两个原厂镜像的 boot 头解析" >> "$OUT"
python3 - <<'PY' >> "$OUT" 2>&1
import struct, hashlib
from pathlib import Path
for name in ("boot.img", "recovery.img"):
    p = Path("/mnt/e/Code/HackIos/out/phone3") / name
    if not p.is_file():
        print(name, "缺失"); continue
    d = p.read_bytes()
    page = struct.unpack_from("<I", d, 36)[0]
    ver = struct.unpack_from("<I", d, 40)[0]
    ks, rs, ss = struct.unpack_from("<3I", d, 8)
    dtb = struct.unpack_from("<I", d, 44)[0]
    cmd = d[48:48+24].split(b"\0")[0].decode("ascii", "replace")
    print(f"{name}: {len(d):,} B sha {hashlib.sha256(d).hexdigest()[:24]}… "
          f"magic={d[:8]!r} page={page} hdr_ver={ver} kernel={ks:,} ramdisk={rs:,} second={ss:,} dtb={dtb:,}")
    print(f"   cmdline[:24]={cmd!r}")
    print(f"   name={d[72:96].split(chr(0).encode())[0]!r}")
PY
echo "== 3. 我们的菜单镜像同字段对照" >> "$OUT"
python3 - <<'PY' >> "$OUT" 2>&1
import struct, hashlib
d = open("/mnt/e/Code/HackIos/out/images/umi-uefi-menu.img", "rb").read()
print(f"umi-uefi-menu.img: {len(d):,} B sha {hashlib.sha256(d).hexdigest()[:24]}… "
      f"magic={d[:8]!r} page={struct.unpack_from('<I',d,36)[0]} hdr_ver={struct.unpack_from('<I',d,40)[0]}")
PY
echo WROTE >> "$OUT"
