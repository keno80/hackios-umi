#!/bin/bash
# 从常驻 QEMU 窗口抓当前帧（QMP screendump），落到 E: 方便直接在对话里看
set -u
L=/home/unixnu/code/umi-work-pin/out/umi-qemu/live
SOCK=$L/qmp.sock
OUT=$L/shot.png
DST=/mnt/e/Code/HackIos/out/qemu-live-screen.png
[ -S "$SOCK" ] || { echo "没有 QMP socket，先跑 qemu-live"; exit 1; }
rm -f "$OUT"
python3 - "$SOCK" <<'PY'
import json, socket, sys
s = socket.socket(socket.AF_UNIX)
s.connect(sys.argv[1])
s.settimeout(20)
def rd():
    buf = b""
    while b"\n" not in buf:
        chunk = s.recv(4096)
        if not chunk:
            break
        buf += chunk
    return buf
rd()  # greeting
s.sendall(b'{"execute":"qmp_capabilities"}\n'); rd()
s.sendall(json.dumps({"execute": "screendump",
                      "arguments": {"filename": "/home/unixnu/code/umi-work-pin/out/umi-qemu/live/shot.png"}}).encode() + b"\n")
print(rd().decode(errors="replace").strip())
PY
if [ -f "$OUT" ]; then
  DST=/mnt/e/Code/HackIos/out/qemu-live-screen.ppm
  cp "$OUT" "$DST"
  echo "已存 $DST（$(file -b "$OUT")）"
  if python3 -c "import PIL" 2>/dev/null; then
    python3 - "$OUT" /mnt/e/Code/HackIos/out/qemu-live-screen.png <<'PY'
import sys
from PIL import Image
Image.open(sys.argv[1]).save(sys.argv[2])
print("PNG:", sys.argv[2])
PY
  fi
else
  echo "screendump 没产出文件"
fi
