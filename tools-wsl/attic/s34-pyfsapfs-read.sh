#!/bin/bash
# 接 s33：卷是 **0 基**（get_number_of_volumes()=1 但 get_volume(1) 越界 ⇒ get_volume(0)）；
# 而且 volume 上有 get_file_entry_by_path —— 能按路径直接取文件，不用整树递归。
# 本文件：确认 0 基、列出 cryptex 顶层、把 file_entry 的完整方法面打出来（找读字节的入口），
# 并真读一个文件的头 4KB 验 Mach-O 魔数。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s34-pyfsapfs-read.txt 2>&1
SYSOS=/home/unixnu/code/umi-work-pin/out/umi-xnu/ipsw/21H461/044-76034-038.dmg

python3 - "$SYSOS" <<'PY'
import pyfsapfs, sys, struct
ct = pyfsapfs.container(); ct.open(sys.argv[1])
vol = ct.get_volume(0)
print('  volume 0 name =', vol.name if not callable(getattr(vol,'name',None)) else vol.get_name())
root = vol.get_root_directory()
n = root.get_number_of_sub_file_entries()
print(f'  根目录子项数 = {n}')
for k in range(n):
    e = root.get_sub_file_entry(k)
    print(f'    [{k}] name={e.name} mode={getattr(e,"file_mode",None)} size={e.get_size() if hasattr(e,"get_size") else "?"}')
print('  file_entry 全方法:', [m for m in dir(root) if not m.startswith('_')])
print()
print('== 按路径取几个候选真件 ==')
for p in ('/usr/lib/dyld', '/sbin/launchd', '/usr/libexec/launchd', '/sbin/reboot',
          '/usr/libexec/mobile_activation_tool', '/bin/launchd', '/usr/sbin/cfprefsd',
          '/System/Library/Cryptexs', '/usr/libexec/xpcd'):
    try:
        e = vol.get_file_entry_by_path(p)
        print(f'  {p}: size={e.get_size()} mode={e.file_mode}')
    except Exception as ex:
        print(f'  {p}: 失败 {type(ex).__name__} {str(ex)[:90]}')
print()
print('== 读 /usr/lib/dyld 头 4KB（找 io_entry 的等价入口）==')
try:
    e = vol.get_file_entry_by_path('/usr/lib/dyld')
    io = e.io_entry() if hasattr(e, 'io_entry') else None
    print('  io_entry:', type(io).__name__ if io else None, [m for m in dir(io) if not m.startswith('_')] if io else '')
    if io is not None:
        data = None
        for m in ('read_range', 'read_offset'):
            if hasattr(io, m):
                try:
                    data = getattr(io, m)(0, 4096); break
                except Exception as ex:
                    print('   ', m, '失败', ex)
        if data:
            print('  头 16 字节:', data[:16].hex())
            magic = struct.unpack_from('<I', data, 0)[0]
            cput, sub, nc = struct.unpack_from('<IiI', data, 4)
            flags, = struct.unpack_from('<I', data, 16)
            print(f'  magic=0x{magic:08x} cput=0x{cput:x} sub=0x{sub:x} ncmds={nc} filetype={flags & 0xf}')
except Exception as ex:
    print('  失败:', type(ex).__name__, ex)
PY
