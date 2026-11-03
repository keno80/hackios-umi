#!/usr/bin/env python3
"""DarwinBoot 是否真的进了 FD？（FFS 与 FD 字节比对）"""
import glob, os, struct

B = "/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB"
fd = open(f"{B}/FV/SILICIUM_UEFI.fd", "rb").read()


def guid_bytes(u):
    p = u.split("-")
    return struct.pack("<IHH", int(p[0], 16), int(p[1], 16), int(p[2], 16)) + bytes.fromhex(p[3] + p[4])


db = sorted(glob.glob(f"{B}/FV/Ffs/*DarwinBoot/*.ffs"))[0]
raw = open(db, "rb").read()
pe32 = open(db.replace(".ffs", "SEC2.1.pe32"), "rb").read()
print("ffs 头 16 字节:", raw[:16].hex(), " 在 FD 偏移:", fd.find(raw[:16]))
print("DarwinBoot GUID 在 FD 偏移:", fd.find(guid_bytes("1B64AF87-8415-4B57-9B16-680D70913B9F")))
print("pe32 中段 200 B 在 FD 偏移:", fd.find(pe32[6000:6200]))

hit = 0
names = sorted(os.path.basename(d) for d in glob.glob(f"{B}/FV/Ffs/*"))
for name in names:
    found = fd.find(guid_bytes(name[:36])) >= 0
    hit += found
    if any(k in name[36:].lower() for k in ("darwin", "bds", "platform", "menu")):
        print("  %-44s GUID 在 FD: %s" % (name[36:], found))
print("共 %d 个 FFS，GUID 出现在 FD：%d" % (len(names), hit))
for f in glob.glob(f"{B}/FV/*.inf"):
    txt = open(f, encoding="utf-8", errors="replace").read()
    keys = [l.strip() for l in txt.splitlines() if "arwin" in l or "BdsDxe" in l]
    if keys:
        print(os.path.basename(f), "->", keys[:6])
