#!/usr/bin/env python3
"""H 步判读：把 screen.png 按顶部往下 16 等分，报每段里各色占比。
内核画的 band1/2/3 分别落在第 2/3/4 段（第 1 段是 darwinboot 的绿带）。"""
import sys
from PIL import Image

NAMES = {"green": (0, 255, 0), "red": (255, 0, 0), "blue": (0, 0, 255),
         "yellow": (255, 255, 0)}

img = Image.open(sys.argv[1]).convert("RGB")
w, h = img.size
px = img.load()
print("screen %dx%d" % (w, h))
step = h // 16
for band in range(16):
    y0, y1 = band * step, (band + 1) * step if band < 15 else h
    tally = {k: 0 for k in NAMES}
    total = 0
    for y in range(y0, y1, 2):
        for x in range(0, w, 2):
            r, g, b = px[x, y]
            total += 1
            for name, (cr, cg, cb) in NAMES.items():
                if abs(r - cr) < 60 and abs(g - cg) < 60 and abs(b - cb) < 60:
                    tally[name] += 1
    if not total:
        continue
    top = max(tally, key=tally.get)
    frac = tally[top] / total
    if frac > 0.30:
        print("band %2d  %-6s %5.1f%%" % (band + 1, top, frac * 100))
    else:
        print("band %2d  (无纯色带，最高 %s %.1f%%)" % (band + 1, top, frac * 100))
