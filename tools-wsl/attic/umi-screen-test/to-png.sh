#!/bin/bash
set -uo pipefail
cd /home/unixnu/umi-screen-test
python3 - <<'PY'
import struct, zlib


def read_ppm(path):
    with open(path, 'rb') as handle:
        data = handle.read()
    head = data.split(b'\n', 3)
    width, height = (int(value) for value in head[1].split())
    return width, height, head[3]


def write_png(path, width, height, pixels, stride):
    rows = b''.join(b'\x00' + pixels[y * stride:(y + 1) * stride] for y in range(height))

    def chunk(tag, body):
        return (struct.pack('>I', len(body)) + tag + body +
                struct.pack('>I', zlib.crc32(tag + body) & 0xffffffff))

    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(rows, 6))
    png += chunk(b'IEND', b'')
    with open(path, 'wb') as handle:
        handle.write(png)
    print(path, width, height)


def crop(pixels, width, height, stride, top, bottom):
    top = max(0, min(top, height))
    bottom = max(top, min(bottom, height))
    return b''.join(pixels[y * stride:(y + 1) * stride] for y in range(top, bottom))


def content_rows(pixels, width, stride):
    last = -1
    for y in range(len(pixels) // stride):
        row = pixels[y * stride:(y + 1) * stride]
        if any(row[x] for x in range(0, len(row), 64)):
            last = y
    return last


width, height, pixels = read_ppm('out.ppm')
stride = width * 3
write_png('log-top.png', width, 700, crop(pixels, width, height, stride, 0, 700), stride)
write_png('log-bottom.png', width, 700, crop(pixels, width, height, stride, height - 700, height), stride)

width, height, pixels = read_ppm('out-openloop.ppm')
stride = width * 3
last = content_rows(pixels, width, stride)
top = max(0, last - 699)
write_png('openloop.png', width, last + 1 - top, crop(pixels, width, height, stride, top, last + 1), stride)
print('openloop content ends at row', last)

width, height, pixels = read_ppm('out-panic.ppm')
stride = width * 3
for name, top, bottom in (('panic-a', 150, 930), ('panic-b', 930, 1710), ('panic-c', 1710, 2340)):
    write_png(name + '.png', width, bottom - top, crop(pixels, width, height, stride, top, bottom), stride)
PY
cp /home/unixnu/umi-screen-test/log-top.png /mnt/e/Code/HackIos/out/rev2-log-top.png
cp /home/unixnu/umi-screen-test/log-bottom.png /mnt/e/Code/HackIos/out/rev2-log-bottom.png
cp /home/unixnu/umi-screen-test/openloop.png /mnt/e/Code/HackIos/out/rev3-openloop.png
cp /home/unixnu/umi-screen-test/panic-a.png /mnt/e/Code/HackIos/out/rev2-panic-a.png
cp /home/unixnu/umi-screen-test/panic-b.png /mnt/e/Code/HackIos/out/rev2-panic-b.png
cp /home/unixnu/umi-screen-test/panic-c.png /mnt/e/Code/HackIos/out/rev2-panic-c.png
echo copied
