#!/bin/bash
OUT=/mnt/e/Code/HackIos/out/menu-final-check.txt
: > "$OUT"
WS=/home/unixnu/code/umi-work-pin
cd "$WS" || exit 1

echo "== 1. 解包逐字节比对（gzip.decompressobj）" >> "$OUT"
python3 - <<'PY' >> "$OUT" 2>&1
import struct, zlib, hashlib
img = open("out/umi/boot/umi-uefi-menu.img", "rb").read()
ks = struct.unpack_from("<I", img, 8)[0]
seg = img[4096:4096 + ks]
o = zlib.decompressobj(16 + zlib.MAX_WBITS)
raw = o.decompress(seg)
print("inflated %d, unused trailing %d (= DTB?)" % (len(raw), len(o.unused_data)))
fd = open("/home/unixnu/code/uefi-umi-b/Build/umiPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd", "rb").read()
print("combined = shim+FD ->", len(raw), "FD tail match:", raw[-len(fd):] == fd)
print("shim head ARM64:", raw[56:60], "text_end=%#x image_size=%#x" % struct.unpack_from("<2Q", raw, 8))
print("DTB in image sha:", hashlib.sha256(o.unused_data).hexdigest())
print("running.dtb sha :", hashlib.sha256(open("out/umi/dtb/umi-running.dtb","rb").read()).hexdigest())
print("dtb_node patched:", len(o.unused_data) != 947766)
PY

echo "== 2. board.toml 是否声明 dtb_node" >> "$OUT"
grep -n "dtb_node" "$WS/devices/umi/board.toml" >> "$OUT" 2>&1

echo "== 3. verify_umi_fd.py 能不能跑（FD 内容闸门）" >> "$OUT"
python3 tools/verify_umi_fd.py --expected-fd-sha256 6ef6a279e297d5296224a94ae07c12897d41f1035d46074e003ce2642f315fbc 2>&1 | tail -25 >> "$OUT"

echo "== 4. 交付件" >> "$OUT"
ls -la /mnt/e/Code/HackIos/out/umi-uefi-menu.img >> "$OUT" 2>&1
echo "WROTE"
