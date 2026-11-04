#!/bin/bash
set -u
O=/mnt/e/Code/HackIos/out
{
  cd "$O" || exit 1
  python3 - <<'PY'
from PIL import Image
im = Image.open("web-check.png")
print("size", im.size)
w, h = im.size
im.crop((0, 0, min(w, 1400), 560)).save("web-top.png")
im.crop((0, min(420, max(0, h - 600)), min(w, 1400), min(420 + 600, h))).save("web-mid.png")
PY
  ls -l web-top.png web-mid.png
} > "$O/crop.txt" 2>&1
