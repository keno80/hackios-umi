#!/bin/bash
set -u
B=/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB
LOG=/mnt/e/Code/HackIos/out/probes/darwinboot-bytes.txt
python3 - "$B" <<'PY' > "$LOG" 2>&1
import glob, hashlib, os, struct, sys
B = sys.argv[1]
fd = open(f"{B}/FV/SILICIUM_UEFI.fd", "rb").read()
efi = f"{B}/AARCH64/DarwinBootPkg/Driver/DarwinBoot/OUTPUT/DarwinBoot.efi"
blob = open(efi, "rb").read()
print("FD %d B sha %s" % (len(fd), hashlib.sha256(fd).hexdigest()[:16]))
print("DarwinBoot.efi %d B sha %s" % (len(blob), hashlib.sha256(blob).hexdigest()[:16]))
# FFS 里存的是压缩后的 TE/PE32；先试原文命中，再试 LZMA 段的开头若干字节
probes = [("整个 .efi", blob), (".text 前 4 KB", blob[0x200:0x200+4096]),
          ("入口附近 512 B", blob[0x200:0x400])]
for name, p in probes:
    print("  命中 %-16s : %s" % (name, fd.find(p) if fd.find(p) >= 0 else "无"))
# FFS 目录里真正的载荷文件
ffs = sorted(glob.glob(f"{B}/FV/Ffs/1B64AF87-8415-4B57-9B16-680D70913B9FDarwinBoot/*"))
print("FFS 条目：")
for f in ffs:
    d = open(f, "rb").read()
    print("  %-28s %6d B sha %s" % (os.path.basename(f), len(d), hashlib.sha256(d).hexdigest()[:12]))
# 未压缩的 PE32 段应原样出现在 FD 中
for f in ffs:
    d = open(f, "rb").read()
    if b"PE\0\0" in d[:8] or d[:2] == b"MZ":
        off = fd.find(d[:16384])
        print("  FD 内含该载荷前 16 KB：%s" % ("是 @%d" % off if off >= 0 else "否"))
print("菜单相关：umi.dsc 路径")
for p in glob.glob("/home/unixnu/code/uefi-umi-b/Platform/**/umi.dsc", recursive=True):
    txt = open(p, encoding="utf-8", errors="replace").read()
    print("  %s  DarwinBoot 提及 %d 次" % (p, txt.lower().count("darwinboot")))
PY
