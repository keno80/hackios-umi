#!/bin/bash
# 接 s30：pyfsapfs 没有 volume_system 这个属性，20201107 版 libyal 绑定用的是 handle()。
# 本文件不做业务，只把 API 面 dump 出来，免得再猜第三轮。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s32-pyfsapfs-api.txt 2>&1
SYSOS=/home/unixnu/code/umi-work-pin/out/umi-xnu/ipsw/21H461/044-76034-038.dmg

python3 - "$SYSOS" <<'PY'
import pyfsapfs, sys
names = [n for n in dir(pyfsapfs) if not n.startswith('_')]
print('== 模块公开名 ==')
print('  ', names)
print('  version:', pyfsapfs.get_version() if hasattr(pyfsapfs,'get_version') else '?')
h = None
for ctor in ('handle','volume_system','apfs_handle'):
    if hasattr(pyfsapfs, ctor):
        print(f'== 用 {ctor}() 打开 ==')
        h = getattr(pyfsapfs, ctor)()
        break
print('  handle 方法:', [m for m in dir(h) if not m.startswith('_')])
try:
    h.open(sys.argv[1])
    print('  open OK; number_of_volumes =', h.get_number_of_volumes())
except Exception as e:
    print('  open 失败:', type(e).__name__, e)
    raise SystemExit
for i in range(1, h.get_number_of_volumes()+1):
    v = h.get_volume(i)
    print(f'== volume {i} ==')
    print('  方法:', [m for m in dir(v) if not m.startswith('_')])
    print('  name:', v.name, 'type:', type(v).__name__)
    try:
        r = v.get_root_directory()
        print('  root 方法:', [m for m in dir(r) if not m.startswith('_')])
        print('  root 子项数:', r.get_number_of_sub_file_entries())
        for k in range(min(r.get_number_of_sub_file_entries(), 30)):
            c = r.get_sub_file_entry(k)
            md = c.metadata
            print(f'    [{k}] name={c.name} type={md.type} size={getattr(md,"size",None)}')
            if k == 0:
                print('      entry 方法:', [m for m in dir(c) if not m.startswith('_')])
                print('      metadata 方法:', [m for m in dir(md) if not m.startswith('_')])
                io = c.io_entry()
                print('      io_entry 方法:', [m for m in dir(io) if not m.startswith('_')])
    except Exception as e:
        print('  root 失败:', type(e).__name__, e)
PY
