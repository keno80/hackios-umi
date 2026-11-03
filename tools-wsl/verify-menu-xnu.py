#!/usr/bin/env python3
"""独立复核 umi-uefi-menu-xnu.img（不依赖 unixnu 自带的 verify）。"""
import hashlib, struct, zlib

WS = "/home/unixnu/code/umi-work-pin"
IMG = f"{WS}/out/umi/boot/umi-uefi-menu-xnu.img"
RAM = f"{WS}/out/umi/boot/umi-uefi-menu-ram.img"
FAT = f"{WS}/out/umi/xnu/umi-xnu-fat.img"
DTB = f"{WS}/out/umi/dtb/umi-running.dtb"
FD = "/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd"

d = open(IMG, "rb").read()
# 本仓 Resources/Scripts/mkbootimg.py 的 v1 字段序（header_version 在字节 40，紧接 page_size）
(ksize, kaddr, rsize, raddr, ssize, saddr, tags, page, hver) = struct.unpack_from("<9I", d, 8)
ram = open(RAM, "rb").read(64)
ram_hdr = struct.unpack_from("<9I", ram, 8)
res = []
res.append(("magic ANDROID!", d[:8] == b"ANDROID!"))
res.append((f"page_size {page}", page == 4096))
res.append((f"header_version {hver}", hver == 1))
res.append((f"kernel_address {hex(kaddr)}", kaddr == 0x8000))
res.append((f"ramdisk_address {hex(raddr)}", raddr == 0x1000000))
res.append((f"tags_address {hex(tags)}", tags == 0x1E00000))
res.append((f"second_size {ssize}", ssize == 0))
res.append((f"ramdisk_size {rsize:,} == 64 MiB", rsize == 67108864))
res.append(("头字段序与已上机验证的 ram 镜像一致（仅 ksize/rsize 不同）",
            [v if i not in (0, 2) else 0 for i, v in enumerate(ram_hdr)]
            == [v if i not in (0, 2) else 0 for i, v in enumerate(
                   (ksize, kaddr, rsize, raddr, ssize, saddr, tags, page, hver))]))

kpages = -(-ksize // page)
rpages = -(-rsize // page)
koff, roff = page, page * (1 + kpages)
res.append((f"kernel 段 {kpages} 页 @ {koff:,}，ramdisk @ {roff:,}", koff + kpages * page == roff))
res.append((f"总大小 {len(d):,} == 头+内核+ramdisk", len(d) == page * (1 + kpages + rpages)))

ksec = d[koff:koff + ksize]
obj = zlib.decompressobj(16 + zlib.MAX_WBITS)
raw = obj.decompress(ksec)
tail = obj.unused_data  # gzip 成员之后的原始字节（应为 DTB + 0 填充）
gz_len = len(ksec) - len(tail)
res.append((f"内核段 gzip {gz_len:,} B，其后即 DTB 魔数", obj.eof and tail[:4] == b"\xd0\x0d\xfe\xed"))
fd_b = open(FD, "rb").read()
tree = open(DTB, "rb").read()
res.append((f"gzip 解压 {len(raw):,} B = shim {len(raw)-len(fd_b):,} + FD {len(fd_b):,}",
            len(raw) - len(fd_b) == 304))
res.append(("FD 尾段 == SILICIUM_UEFI.fd (b4e1acc2…)",
            raw.endswith(fd_b) and hashlib.sha256(fd_b).hexdigest()[:8] == "b4e1acc2"))
res.append(("shim magic 'ARMd'", raw[56:60] == b"ARMd"))
res.append(("内核段尾 DTB == running.dtb (b71de8d8…)",
            tail[:len(tree)] == tree and hashlib.sha256(tree).hexdigest()[:8] == "b71de8d8"))
print("  头 40..64 字节：", d[40:64].hex())
fat_b = open(FAT, "rb").read()
res.append((f"ramdisk 段 == 整卷 umi-xnu-fat.img ({hashlib.sha256(fat_b).hexdigest()[:8]}…)",
            d[roff:roff + len(fat_b)] == fat_b))
KER = f"{WS}/out/umi-xnu/umi/kernel/source-kernel.macho"
STK = f"{WS}/out/umi/xnu/stage2/EFI/UniXNU/Payloads/kernel.macho"
knew = hashlib.sha256(open(KER, "rb").read()).hexdigest()
res.append((f"卷暂存 kernel.macho == 新编 source-kernel.macho ({knew[:8]}…)",
            hashlib.sha256(open(STK, "rb").read()).hexdigest() == knew))

print(f"镜像 {IMG}\n  {len(d):,} B  sha {hashlib.sha256(d).hexdigest()}")
for label, ok in res:
    print(f"  {'OK  ' if ok else 'FAIL'}{label}")
print("RESULT", "ALL-OK" if all(o for _, o in res) else "HAS-FAIL")
