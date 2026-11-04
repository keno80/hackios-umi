#!/bin/bash
# 接 s49：read_buffer 在本绑定里只收 size 一个参数。先把 file_entry 的读/定位方法面打出来，
# 再按「顺序读」与「seek+读」两种取法兜住，把 /sbin/launchd 与 /usr/lib/dyld 落到磁盘并对表上游哈希。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s50-read-fix.txt 2>&1
OUT=/home/unixnu/code/umi-work-pin/out/umi-xnu/apple-el0

timeout 500 python3 - "$OUT" <<'PY' 2>&1
import hashlib, os, pyfsapfs, struct, sys
out = sys.argv[1]
ct = pyfsapfs.container(); ct.open(os.path.join(out, 'apfs.bin'))
v = ct.get_volume(0)
e0 = v.get_file_entry_by_path('/sbin/launchd')
print('file_entry 方法面：', [m for m in dir(e0) if not m.startswith('_')])
print('launchd size =', e0.get_size())

def slurp(entry, size):
    # 姿势一：顺序 read_buffer(size)
    try:
        buf = bytearray()
        while len(buf) < size:
            chunk = entry.read_buffer(min(1 << 22, size - len(buf)))
            if not chunk:
                break
            buf += chunk
        if len(buf) == size:
            return bytes(buf), 'sequential'
    except Exception as ex:
        print('  顺序读失败:', type(ex).__name__, str(ex)[:120])
    # 姿势二：seek_offset + read_buffer
    for name in ('seek_offset', 'seek', 'offset_set'):
        fn = getattr(entry, name, None)
        if not fn:
            continue
        try:
            buf = bytearray(); pos = 0
            while pos < size:
                fn(pos)
                chunk = entry.read_buffer(min(1 << 22, size - pos))
                if not chunk:
                    break
                buf += chunk; pos += len(chunk)
            if len(buf) == size:
                return bytes(buf), name
        except Exception as ex:
            print(f'  {name} 读失败:', type(ex).__name__, str(ex)[:120])
    return None, None

期望 = {'/sbin/launchd': '8cec9a3c44a443b08e977ccc5d577850316ad428c575dc01f09b018dbd5b6a25',
        '/usr/lib/dyld': 'f8df3c58fae6e409db740df22c98aa699aee110b73523541a63f1bd5e23cf705'}
for path, want in 期望.items():
    entry = v.get_file_entry_by_path(path)
    if entry is None:
        print(f'{path}: 该卷无此件'); continue
    size = entry.get_size()
    data, how = slurp(entry, size)
    if data is None:
        print(f'{path}: size={size} 读取失败'); continue
    got = hashlib.sha256(data).hexdigest()
    magic, cputype, cpusub, filetype = struct.unpack_from('<4I', data)
    dest = os.path.join(out, os.path.basename(path))
    open(dest, 'wb').write(data)
    ncmd, = struct.unpack_from('<I', data, 16)
    print(f'{path}: size={len(data)} 取法={how} macho={magic == 0xFEEDFACF and cputype == 0x100000C} '
          f'filetype={filetype} ncmds={ncmd}')
    print(f'   sha256={got}  对上游 {"一致 ✔" if got == want else "不一致 ✘"}')
    print(f'   落盘 {dest}')
PY
ls -l "$OUT"
