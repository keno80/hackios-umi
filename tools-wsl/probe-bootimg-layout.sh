#!/bin/bash
# bootimg 布局到底怎么排：kernel/ramdisk/second 各自装什么、由什么决定
W=/home/unixnu/code/umi-work-pin
U=$W/sources/UniXNU
echo "== unixnu CLI 里 bootimg 的实现文件 =="
grep -rln "ANDROID!" $U --include=*.py 2>/dev/null | head -5
F=$(grep -rln "second" $U --include=*.py 2>/dev/null | head -3)
echo "candidates: $F"
for f in $F; do
  echo "----- $f"
  grep -n -B4 -A12 "second" "$f" | head -70
done

echo "== 现存 boot 镜像与各自的三段大小 =="
ls -la $W/out/umi/boot/ 2>/dev/null
python3 - "$W/out/umi/boot" <<'PY'
import struct, sys, pathlib
for p in sorted(pathlib.Path(sys.argv[1]).glob("*.img")):
    d = p.open("rb").read(4096)
    if d[:8] != b"ANDROID!":
        continue
    k, r, s = struct.unpack_from("<3I", d, 8)
    page, = struct.unpack_from("<I", d, 36)
    names = struct.unpack_from("<32s32s32s", d, 40)
    print(f"{p.name:32s} page={page} kernel={k} ramdisk={r} second={s} tags={names[2][:16]!r}")
    body = d[page:page+min(k, 64)]
    print("    kernel head:", body[:16].hex(), body[:8])
PY

