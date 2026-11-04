#!/bin/bash
# 接 s29：模块名是 pyfsapfs（不是 fsapfs）。apfs-dkms 那个 iF 是 E 步留下的半配置状态，
# 不影响 python 绑定（ii python3-fsapfs 已装好），不动它。
# 本文件：浅走摸清 API 与 type 编码 → 全扫 Cryptex1,SystemOS，收 MH_EXECUTE 的真 Apple arm64 件。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s30-pyfsapfs-scan.txt 2>&1
SYSOS=/home/unixnu/code/umi-work-pin/out/umi-xnu/ipsw/21H461/044-76034-038.dmg

echo "== 1. 浅走：根目录与一级子项 =="
timeout 300 python3 - "$SYSOS" <<'PY'
import pyfsapfs, sys
vs = pyfsapfs.volume_system(); vs.open(sys.argv[1])
v = vs.get_volume(1)
print('  volume name:', v.name)
root = v.get_root_directory()
print('  root type:', type(root).__name__, 'attrs:', [a for a in dir(root) if not a.startswith('_')][:24])
n = root.get_number_of_sub_file_entries()
print('  根目录条目数:', n)
for i in range(min(n, 40)):
    c = root.get_sub_file_entry(i)
    md = c.metadata
    print(f'    [{i}] name={c.name} type={md.type} size={getattr(md,"size",None)} xtype={getattr(md,"xtype",None)}')
PY

echo
echo "== 2. 全扫：收 Mach-O MH_EXECUTE（只读头 4KB，每 5000 个报一次进度）=="
timeout 1200 python3 - "$SYSOS" <<'PY'
import pyfsapfs, struct, sys, time
vs = pyfsapfs.volume_system(); vs.open(sys.argv[1])
v = vs.get_volume(1)
execs, machos, dirs, files, errs, types = [], [], 0, 0, 0, {}
t0 = time.time()
def read_head(entry, size):
    io = entry.io_entry()
    try:
        return io.read_range(0, min(4096, size))
    except Exception:
        return io.read_offset(0, min(4096, size))
def walk(entry, path):
    global dirs, files, errs
    try:
        n = entry.get_number_of_sub_file_entries()
    except Exception:
        return
    for i in range(n):
        c = entry.get_sub_file_entry(i)
        try:
            name = c.name.decode('utf-8','replace') if isinstance(c.name, bytes) else str(c.name)
        except Exception:
            name = '?'
        p = path + '/' + name
        t = getattr(c.metadata, 'type', None)
        types[t] = types.get(t, 0) + 1
        if t == 2:                      # directory
            dirs += 1
            walk(c, p)
            continue
        if t != 1:                      # 只看 regular
            continue
        files += 1
        if files % 5000 == 0:
            print(f'    ... {files} 文件, {len(execs)} 可执行, {time.time()-t0:.0f}s', flush=True)
        size = getattr(c.metadata, 'size', 0) or 0
        if not (4096 <= size < 64*1024*1024):
            continue
        try:
            h = read_head(c, size)
        except Exception:
            errs += 1
            continue
        if not h or h[:4] != b'\xcf\xfa\xed\xfe':
            continue
        cput, sub, ncmds = struct.unpack_from('<IiI', h, 4)
        flags, = struct.unpack_from('<I', h, 16)
        ft = flags & 0xf
        machos.append((ft, p, cput))
        if ft == 2:
            execs.append((size, p, cput, sub))
print(f'  type 直方图: {types}')
print(f'  目录={dirs} 文件={files} 头读失败={errs} Mach-O={len(machos)} MH_EXECUTE={len(execs)} 用时={time.time()-t0:.0f}s')
print('  --- filetype 分布:', sorted(set(m[0] for m in machos)))
print('  --- 最小的 25 个 MH_EXECUTE:')
for sz, p, c, s in sorted(execs)[:25]:
    print(f'    {sz:>10}  cput=0x{c:x} sub=0x{s:x}  {p}')
print('  --- 名字含 launchd/dyld/backboardd 的:')
for sz, p, c, s in execs:
    if any(k in p for k in ('launchd', '/dyld', 'backboardd', 'SpringBoard')):
        print(f'    {sz:>10}  {p}')
PY
