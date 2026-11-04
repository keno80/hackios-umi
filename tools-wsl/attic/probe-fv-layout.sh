#!/bin/bash
set -u
B=/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB
LOG=/mnt/e/Code/HackIos/out/probes/fv-layout.txt
{
  echo "== FV 目录"
  ls -la "$B/FV" | head -20
  echo "== DarwinBoot 出现在 FV 文本产物"
  grep -rl -i darwinboot "$B/FV" 2>/dev/null | head
  echo "== FV 里的 LZMA/压缩 GUID"
  python3 - "$B/FV/SILICIUM_UEFI.fd" <<'PY'
import struct, sys
d = open(sys.argv[1], "rb").read()
def gb(u):
    p = u.split("-")
    return struct.pack("<IHH", int(p[0],16), int(p[1],16), int(p[2],16)) + bytes.fromhex(p[3]+p[4])
for name, u in [("LZMA", "EE4E5898-3914-4259-9D6E-07D7B2D84238"),
                ("Brotli", "D6A2CB7F-B651-4219-8734-331876413A8F"),
                ("SimpleDecompress", "03E3E601-BA44-41D2-96E6-95A7EF265C5C")]:
    print("  %-18s 首命中 %s" % (name, d.find(gb(u))))
i = d.find(b"_FV_HDR")
print("  _FV_HDR @", i)
if i >= 0:
    fv = d[i+16:]
    print("  FV GUID", fv[:16].hex(), "Length", struct.unpack_from("<Q", fv, 32)[0],
          "Attrs", hex(struct.unpack_from("<I", fv, 44)[0]))
    import collections
    b = d[i+16+48:]
    # FFS 头扫描：type(1) attrs(1) state(1) 0x00 guid(16) size(3)
    n = 0
    off = 0
    while off + 24 <= len(b) and n < 200:
        t, a, s = b[off], b[off+1], b[off+2]
        if s == 0x07 and t in (0x05, 0x06, 0x07, 0x09):
            n += 1
            size = int.from_bytes(b[off+20:off+23], "little")
            off += max(size, 8)
        else:
            off += 1
    print("  扫到 FFS 文件数约", n)
PY
  echo "== FDF 里的压缩与 DarwinBoot"
  grep -rn -i -E 'compress|darwinboot' "$B/../../Platform/Xiaomi/umiPkg"/*.fdf 2>/dev/null | head -12
} > "$LOG" 2>&1
