from PIL import Image
import os
os.chdir("/mnt/e/Code/HackIos/out")
im = Image.open("web-check.png")
w, h = im.size
print("size", w, h)
im.crop((0, 0, min(w, 1400), min(560, h))).save("web-top.png")
top = max(0, h - 620)
im.crop((0, top, min(w, 1400), min(top + 620, h))).save("web-mid.png")
for f in ("web-top.png", "web-mid.png"):
    print(f, os.path.getsize(f))
