#!/bin/bash
# 接 s47：ipsw 能解 OS dmg 的 UDIF（blkx 里 MBR/Primary GPT/Apple_APFS/Backup GPT 全列出来了），
# 只是默认「整盘解密」路径踩了个空文件名 bug。它有 -p/-r 按分区抽取 ⇒ 直接抽 Apple_APFS 段。
# 抽出来就是标准 APFS 容器（4096 对齐、无 bvx 头），libfsapfs 应当能走穿 B-tree。
set -u
exec > /mnt/e/Code/HackIos/out/probes/s48-carve-apfs.txt 2>&1
IPSW=/mnt/d/tools/ipsw/ipsw
IMG=/home/unixnu/code/umi-work-pin/out/umi-xnu/ipsw/21H461
OS=$IMG/044-76040-038.dmg
OUT=/home/unixnu/code/umi-work-pin/out/umi-xnu/apple-el0
mkdir -p "$OUT"
rm -f "$OUT"/os.raw "$OUT"/osdecode.* "$OUT"/cx.head64.raw

echo "== 1. 按正则抽 Apple_APFS 分区 =="
timeout 560 $IPSW disk dmg "$OS" -r 'Apple_APFS' -o "$OUT/apfs.bin" -V 2>&1 | tail -20
ls -l "$OUT" | head

echo
echo "== 2. 若 1 失败，按序号试 -p 1..4 =="
if [ ! -s "$OUT/apfs.bin" ]; then
  for p in 1 2 3 4; do
    echo "--- -p $p ---"
    timeout 300 $IPSW disk dmg "$OS" -p $p -o "$OUT/apfs-p$p.bin" -V 2>&1 | tail -4
    ls -l "$OUT/apfs-p$p.bin" 2>/dev/null
  done
fi

echo
echo "== 3. 抽到的东西身份确认 =="
for f in "$OUT"/apfs.bin "$OUT"/apfs-p*.bin; do
  [ -s "$f" ] || continue
  echo "--- $f ($(stat -c %s "$f") B) ---"
  od -An -tx1z -N32 "$f"
  python3 - "$f" <<'PY'
import struct, sys
b = open(sys.argv[1], 'rb').read(256)
print('  magic', b[:8], 'blocksize?', struct.unpack_from('<Q', b, 8)[0],
      'blocks?', struct.unpack_from('<Q', b, 16)[0], 'uuid', b[0x58:0x68].hex())
PY
done

echo
echo "== 4. libfsapfs 能不能走到根目录并列出顶层 =="
for f in "$OUT"/apfs.bin "$OUT"/apfs-p*.bin; do
  [ -s "$f" ] || continue
  echo "--- fsapfsinfo $f ---"
  timeout 180 fsapfsinfo "$f" 2>&1 | head -20
  timeout 180 python3 - "$f" <<'PY' 2>&1 | head -30
import pyfsapfs, sys
ct = pyfsapfs.container(); ct.open(sys.argv[1])
v = ct.get_volume(0)
print('volume:', v.get_name())
r = v.get_root_directory()
n = r.get_number_of_sub_file_entries()
print('root children:', n)
for k in range(min(n, 30)):
    e = r.get_file_entry(k)
    print('  ', e.get_name(), e.get_size(), 'dir' if e.is_dir_root else '')
PY
  break
done

echo
echo "== 5. 若根目录可列：直接取 /sbin/launchd 与 /usr/lib/dyld 并核对上游哈希 =="
timeout 300 python3 - "$OUT" <<'PY' 2>&1 | head -40
import glob, hashlib, os, pyfsapfs, sys
out = sys.argv[1]
cands = sorted(glob.glob(os.path.join(out, 'apfs*.bin')), key=os.path.getsize, reverse=True)
if not cands:
    raise SystemExit('没有抽出的分区')
ct = pyfsapfs.container(); ct.open(cands[0])
for vi in range(ct.get_number_of_volumes()):
    v = ct.get_volume(vi)
    print('volume', vi, v.get_name())
    for path in ('/sbin/launchd', '/usr/lib/dyld'):
        try:
            e = v.get_file_entry_by_path(path)
        except Exception as ex:
            print('  ', path, '查不到:', str(ex).split('\n')[0][:120]); continue
        if not e:
            print('  ', path, '不存在'); continue
        data = e.read_bytes(e.get_size())
        d = os.path.join(out, os.path.basename(path))
        open(d, 'wb').write(data)
        print(f'  {path} size={len(data)} sha256={hashlib.sha256(data).hexdigest()}')
print('上游期望 launchd sha256=8cec9a3c44a443b08e977ccc5d577850316ad428c575dc01f09b018dbd5b6a25')
print('上游期望 dyld   sha256=f8df3c58fae6e409db740df22c98aa699aee110b73523541a63f1bd5e23cf705')
PY
ls -l "$OUT" 2>/dev/null | head
