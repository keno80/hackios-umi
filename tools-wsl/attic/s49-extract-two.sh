#!/bin/bash
# 接 s48：ipsw 抽出 Apple_APFS 分区 ⇒ libfsapfs 能列 OS 卷根目录（17 项），
# get_file_entry_by_path('/sbin/launchd') 已返回条目，只是 read_bytes 名字错了（应为 read_buffer）。
# 本文件把真件取出来并与上游 fixture 的期望哈希对表。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s49-extract-two.txt 2>&1
OUT=/home/unixnu/code/umi-work-pin/out/umi-xnu/apple-el0

timeout 420 python3 - "$OUT" <<'PY' 2>&1
import hashlib, os, pyfsapfs, struct, sys
out = sys.argv[1]
img = os.path.join(out, 'apfs.bin')
ct = pyfsapfs.container(); ct.open(img)
v = ct.get_volume(0)
print('volume:', v.get_name())
r = v.get_root_directory()
n = r.get_number_of_sub_file_entries()
print('根目录子项：', [r.get_sub_file_entry(i).get_name() for i in range(n)])

def readent(path):
    e = v.get_file_entry_by_path(path) if hasattr(v, 'get_file_entry_by_path') else None
    if e is None:
        return None
    size = e.get_size()
    buf = bytearray()
    while len(buf) < size:
        chunk = e.read_buffer(len(buf), min(1 << 20, size - len(buf)))
        if not chunk:
            raise RuntimeError('read_buffer 返回空')
        buf += chunk
    return bytes(buf)

期望 = {'/sbin/launchd': '8cec9a3c44a443b08e977ccc5d577850316ad428c575dc01f09b018dbd5b6a25',
        '/usr/lib/dyld': 'f8df3c58fae6e409db740df22c98aa699aee110b73523541a63f1bd5e23cf705'}
for path, want in 期望.items():
    try:
        data = readent(path)
    except Exception as ex:
        print(f'{path}: 取失败 {type(ex).__name__}: {str(ex)[:200]}')
        continue
    if data is None:
        print(f'{path}: 该卷里没有')
        continue
    got = hashlib.sha256(data).hexdigest()
    magic, cputype, cpusub, filetype = struct.unpack_from('<4I', data)
    dest = os.path.join(out, os.path.basename(path))
    open(dest, 'wb').write(data)
    print(f'{path}: size={len(data)} macho={magic == 0xFEEDFACF and cputype == 0x100000C} '
          f'cputype={magic:#x}/{cputype:#x} filetype={filetype}')
    print(f'   sha256={got}')
    print(f'   与上游 fixture 期望 {"一致 ✔" if got == want else "不一致 ✘"}')
    print(f'   落盘 {dest} ({os.path.getsize(dest)} B)')
PY

echo
echo "== 附加：这个 OS 卷里还有没有 dyld 的替身/共享缓存 =="
timeout 300 python3 - "$OUT" <<'PY' 2>&1 | head -30
import pyfsapfs, sys, os
img = os.path.join(sys.argv[1], 'apfs.bin')
ct = pyfsapfs.container(); ct.open(img)
v = ct.get_volume(0)
for p in ('/usr/lib/dyld', '/System/Library/Caches/com.apple.dyld',
          '/usr/lib/libSystem.B.dylib', '/sbin/init', '/System/Library/Frameworks'):
    try:
        e = v.get_file_entry_by_path(p)
    except Exception as ex:
        print(f'  {p}: 异常 {str(ex).splitlines()[0][:100]}'); continue
    print(f'  {p}:', '无' if e is None else f'有 size={e.get_size()} dir={e.is_dir()}')
PY
