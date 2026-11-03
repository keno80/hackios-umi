#!/bin/bash
OUT=/mnt/e/Code/HackIos/out/menu-ffs.txt
: > "$OUT"
WS=/home/unixnu/code/umi-work-pin
UEFI=/home/unixnu/code/uefi-umi-b

echo "== FV 目录里的说明件" >> "$OUT"
head -25 "$UEFI/Build/umiPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv.txt" >> "$OUT" 2>&1
echo "--" >> "$OUT"
head -12 "$UEFI/Build/umiPkg/DEBUG_CLANGPDB/FV/FVMAIN_COMPACT.Fv.txt" >> "$OUT" 2>&1

echo "== FFS 链遍历（未压缩 FVMAIN.Fv）" >> "$OUT"
python3 - <<'PY' >> "$OUT" 2>&1
import struct, uuid
data = open("/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv", "rb").read()
print("FVMAIN.Fv", hex(len(data)))
print("sig", data[40:45], "FvLength", hex(struct.unpack_from("<Q", data, 32)[0]),
      "attrs", hex(struct.unpack_from("<I", data, 44)[0]),
      "packed", hex(struct.unpack_from("<H", data, 48)[0]),
      "HeaderLength", hex(struct.unpack_from("<H", data, 50)[0]),
      "revision", data[59])
TYPES = {0x00:"RAW",0x01:"FREEFORM",0x02:"SECURITY_CORE",0x03:"PEI_CORE",0x04:"DXE_CORE",
         0x05:"PEIM",0x06:"DRIVER",0x07:"COMBINED",0x08:"BOOT",0x09:"DEBUG",0x0A:"FVOL",0x0B:"FSP"}
def walk(hl):
    p, rows = hl, []
    while p + 24 <= len(data):
        t, ext, state = data[p], data[p+1], data[p+2]
        size = int.from_bytes(data[p+4:p+7], "little")
        if size == 0 or state not in (0x01,0x02,0x07,0x1f,0x20,0x21,0x22,0x3f):
            break
        guid = uuid.UUID(bytes_le=data[p+8:p+24])
        name = ""
        if ext:
            ext_len = struct.unpack_from("<H", data, p+24)[0]
            q, end = p+24, p+24+ext_len
            while q + 4 <= end:
                e_size = int.from_bytes(data[q:q+3], "little")
                if e_size == 0: break
                if data[q+3] == 0x04:
                    raw = data[q+4:q+e_size]
                    name = raw.decode("utf-16-le", "replace").split("\0")[0]
                q += (e_size + 7)//8*8
        rows.append((TYPES.get(t, hex(t)), str(guid).upper(), size, name))
        p += (size + 7)//8*8
    return rows, p
for hl in (72, 80, 96):
    rows, end = walk(hl)
    ok = len(rows) > 5
    print(f"-- header_length {hl}: {len(rows)} entries, walk ends {hex(end)} vs FvLength {hex(len(data))} {'PICK' if ok else 'skip'}")
    if ok:
        for r in rows:
            print("   %-12s %s %8d  %s" % r)
        break
PY
echo "WROTE" >> "$OUT"
