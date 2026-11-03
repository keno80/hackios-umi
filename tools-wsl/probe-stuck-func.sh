#!/bin/bash
set -u
WS=/home/unixnu/code/umi-work-pin
K=$WS/out/umi-xnu/umi/kernel/source-kernel.macho
ADT=$WS/out/umi/xnu/stage2/EFI/UniXNU/Payloads/kernel.macho.adt
OUT=$WS/out/stuck.txt
: > "$OUT"
echo "kernel=$K" >> "$OUT"
ls -l "$K" >> "$OUT" 2>&1
ls -l "$ADT" >> "$OUT" 2>&1
NM=$(command -v llvm-nm || command -v nm)
echo "NM=$NM" >> "$OUT"
python3 - "$K" "$NM" >> "$OUT" 2>&1 <<'PY'
import subprocess, sys, struct
k, nm = sys.argv[1], sys.argv[2]
target = 0xfffffff007a15f94
data = open(k, 'rb').read()
magic = struct.unpack_from('<I', data, 0)[0]
print('magic %08x' % magic)
ncmds = struct.unpack_from('<I', data, 16)[0]
off = 32
segs = []
for i in range(ncmds):
    cmd, sz = struct.unpack_from('<II', data, off)
    if cmd == 0x19:
        name = data[off+8:off+24].split(b'\0')[0].decode()
        vmaddr, vmsize, fileoff, filesize = struct.unpack_from('<QQQQ', data, off+24)
        segs.append((name, vmaddr, vmsize, fileoff, filesize))
        print('SEG %-12s vm=%016x size=%08x off=%08x fsize=%08x' % (name, vmaddr, vmsize, fileoff, filesize))
    off += sz
hit = None
for name, vmaddr, vmsize, fileoff, filesize in segs:
    if vmaddr <= target < vmaddr + vmsize:
        fo = fileoff + (target - vmaddr)
        hit = (name, fo)
        raw = data[fo:fo+96]
        print('TARGET in seg %s fileoff=%08x' % (name, fo))
        print('hex :', raw.hex())
        print('asc :', ''.join(chr(c) if 32 <= c < 127 else '.' for c in raw))
if hit is None:
    print('TARGET not inside any segment')
print('--- nm neighborhood ---')
try:
    r = subprocess.run([nm, '-n', '--defined-only', k], capture_output=True, text=True, timeout=300)
    lines = [l for l in r.stdout.splitlines() if l.strip()]
    best = None
    idx = None
    for i, l in enumerate(lines):
        parts = l.split(' ', 1)
        try:
            a = int(parts[0], 16)
        except Exception:
            continue
        if a <= target:
            best = (a, l)
            idx = i
        else:
            break
    print('best<==', best)
    if idx is not None:
        for l in lines[max(0, idx-6):idx+8]:
            print('   ', l)
except Exception as e:
    print('nm failed:', e)
PY
echo "== strings near ==" >> "$OUT"
grep -a -o -E '.{0,24}template.{0,24}' "$K" >> "$OUT" 2>&1 | head -20
echo DONE >> "$OUT"
cp "$OUT" /mnt/e/Code/HackIos/out/stuck.txt 2>/dev/null
echo copied
