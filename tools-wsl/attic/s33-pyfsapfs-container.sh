#!/bin/bash
# 接 s32：pyfsapfs 的入口类是 container（模块公开名里有 container/volume/file_entry/volumes）。
# 本文件先把 container 与 volume 的方法面打出来，再做浅走，顺便确认能不能真读出文件头字节。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s33-pyfsapfs-container.txt 2>&1
SYSOS=/home/unixnu/code/umi-work-pin/out/umi-xnu/ipsw/21H461/044-76034-038.dmg

python3 - "$SYSOS" <<'PY'
import pyfsapfs, sys, struct
print('== class 面 ==')
for cls in ('container','volume','volumes','file_entry','file_entries'):
    c = getattr(pyfsapfs, cls, None)
    print(f'  {cls}:', [m for m in dir(c) if not m.startswith('_')][:40] if c else None)
ct = pyfsapfs.container()
ct.open(sys.argv[1])
print('== 打开成功 ==')
for m in ('get_number_of_volumes','get_volume','get_root_directory'):
    print('  has', m, hasattr(ct, m))
try:
    n = ct.get_number_of_volumes(); print('  volumes =', n)
except Exception as e:
    print('  get_number_of_volumes 失败:', e); raise SystemExit
vol = ct.get_volume(1)
print('  volume 方法:', [m for m in dir(vol) if not m.startswith('_')][:40])
print('  volume name:', getattr(vol, 'name', None))
root = vol.get_root_directory()
print('  root 方法:', [m for m in dir(root) if not m.startswith('_')][:40])
cnt = root.get_number_of_sub_file_entries()
print(f'  根目录子项数 = {cnt}')
for k in range(min(cnt, 40)):
    e = root.get_sub_file_entry(k)
    md = getattr(e, 'metadata', None)
    print(f'    [{k}] name={getattr(e,"name",None)} type={getattr(md,"type",None)} size={getattr(md,"size",None)}')
    if k == 0:
        print('      entry 方法:', [m for m in dir(e) if not m.startswith('_')][:40])
        try:
            io = e.io_entry()
            print('      io_entry 方法:', [m for m in dir(io) if not m.startswith('_')][:30])
        except Exception as ex:
            print('      io_entry 失败:', ex)
PY
