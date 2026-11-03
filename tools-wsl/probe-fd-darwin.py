#!/usr/bin/env python3
"""FD <-> COMPACT 一致性 + DarwinBoot 在压缩前 FV 内的落位。"""
import glob, hashlib, os, struct

B = "/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB"
FV = f"{B}/FV"
fd = open(f"{FV}/SILICIUM_UEFI.fd", "rb").read()
compact = open(f"{FV}/FVMAIN_COMPACT.Fv", "rb").read()
main = open(f"{FV}/FVMAIN.Fv", "rb").read()
pe32 = open(sorted(glob.glob(f"{FV}/Ffs/*DarwinBoot/*SEC2.1.pe32"))[0], "rb").read()
guided = open(sorted(glob.glob(f"{FV}/Ffs/*FVMAIN_COMPACT/*guided*"))[0], "rb").read()
res = []
res.append(("FD 与 FVMAIN_COMPACT.Fv 同 sha",
            hashlib.sha256(fd).hexdigest() == hashlib.sha256(compact).hexdigest()))
res.append(("FD 内含 COMPACT 的 GUIDed 段（压缩后的 FVMAIN）",
            fd.find(guided[8:]) >= 0 or fd.find(compact[64:64 + 4096]) >= 0))
res.append(("FVMAIN.Fv（未压缩）内含 DarwinBoot.pe32 中段",
            main.find(pe32[6000:6200]) >= 0))
res.append(("FVMAIN.Fv 内含 'DarwinBoot' ASCII", b"DarwinBoot" in main))
i = main.find(b"DarwinBoot")
res.append((f"FVMAIN.Fv 首次 'DarwinBoot' 偏移 {i:,}（前 1 KB 是 FV 头）", i >= 0))
apriori = [l.strip() for l in open(f"{FV}/FVMAIN.inf", encoding="utf-8", errors="replace")
           if "DarwinBoot" in l or "BdsDxe" in l]
print("APRIORI/FDF 相关行：")
for l in apriori[:8]:
    print("  ", l)
for label, ok in res:
    print(f"  {'OK  ' if ok else 'FAIL'}{label}")
print("RESULT", "ALL-OK" if all(o for _, o in res) else "HAS-FAIL")
