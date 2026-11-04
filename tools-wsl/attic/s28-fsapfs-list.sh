#!/bin/bash
# T 步落地第一趟：装 python3-fsapfs（libyal 的纯 python 绑定，不依赖 FUSE/内核模块），
# 用它打开本机已有的 Cryptex1,SystemOS 裸 APFS 容器，枚举出**真 Apple 的 arm64 EL0 可执行件**。
# 判据：Mach-O 64 位小端 magic 0xfeedfacf + filetype==MH_EXECUTE(2)；只读每个文件头 4KB，不全量读。
# 目的：挑一个最小的真件当 mockfs initrd，第一次让「Apple 签名件 + 我们的 exec/CS 路径」在 QEMU 里出屏。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s28-fsapfs-list.txt 2>&1
SYSOS=/home/unixnu/code/umi-work-pin/out/umi-xnu/ipsw/21H461/044-76034-038.dmg

echo "== 0. 装 python3-fsapfs =="
DEBIAN_FRONTEND=noninteractive apt-get install -y python3-fsapfs 2>&1 | tail -6
python3 -c 'import fsapfs; print("  fsapfs", fsapfs.get_version())' 2>&1

echo
echo "== 1. 打开容器、列卷 =="
python3 - "$SYSOS" <<'PY'
import fsapfs, sys
vs = fsapfs.volume_system()
vs.open(sys.argv[1])
n = vs.get_number_of_volumes()
print('  volumes:', n)
for i in range(1, n + 1):
    v = vs.get_volume(i)
    print(f'  [{i}] name={v.name!r} block_size={v.block_size} total={v.total_blocks} used={v.used_blocks}')
PY

echo
echo "== 2. 浅走（深度 2）：先把 API 与 type 编码摸清，别拿猜的常量跑 900 秒 =="
timeout 300 python3 - "$SYSOS" <<'PY'
import fsapfs, sys, collections
vs = fsapfs.volume_system(); vs.open(sys.argv[1])
v = vs.get_volume(1)
root = v.get_root_directory()
print('  root dir object:', type(root).__name__)
def kids(entry):
    out = []
    try:
        n = entry.get_number_of_sub_file_entries()
        for i in range(n):
            out.append(entry.get_sub_file_entry(i))
    except Exception as e:
        try:
            out = list(entry)
        except Exception as e2:
            print('    迭代失败:', e, e2)
    return out
def nm(c):
    try:
        return c.name.decode('utf-8', 'replace')
    except Exception:
        return str(getattr(c, 'name', '?'))
hist = collections.Counter()
first = kids(root)
print(f'  根目录条目数={len(first)}')
for c in first[:60]:
    t = getattr(getattr(c, 'metadata', None), 'type', None)
    hist[t] += 1
    print(f'    type={t} size={getattr(c, "size", "?")} name={nm(c)}')
print('  第二层（每个一级目录前 8 项）:')
for c in first[:12]:
    t = getattr(getattr(c, 'metadata', None), 'type', None)
    sub = kids(c) if t in (1, 2, 0x00000001, 0x00000002, 0x0000000d) or True else []
    print(f'  /{nm(c)} ({len(sub)})')
    for d in sub[:8]:
        print(f'      type={getattr(getattr(d,"metadata",None),"type",None)} size={getattr(d,"size","?")} {nm(d)}')
PY
