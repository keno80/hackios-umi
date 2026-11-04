#!/bin/bash
# 上一个脚本用 GNU nm 读 Mach-O 拿到 0 行符号。找能读的：llvm-nm / llvm-objdump / python mach-o。
set -u
OUT=/mnt/e/Code/HackIos/out/probes/n13-symbolize.txt
: > "$OUT"
exec >>"$OUT" 2>&1
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}
OBJ=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/mach.development.bcm2837.unstripped.noctf

echo "== 1. 候选工具 =="
ls -1 $TC/bin 2>/dev/null | grep -i 'nm\|objdump\|symbolizer' | head
ls -1 $TC/CommandLineTools/usr/bin 2>/dev/null | grep -i '^llvm-nm\|nm$\|objdump' | head
which llvm-nm llvm-objdump 2>/dev/null

SYM=""
for t in "$TC/bin/llvm-nm" "$TC/CommandLineTools/usr/bin/llvm-nm" "$TC/llvm/bin/llvm-nm" llvm-nm; do
  if [ -x "$t" ] || command -v "$t" >/dev/null 2>&1; then
    "$t" -n "$OBJ" > /tmp/syms.txt 2>/tmp/syms.err
    n=$(wc -l < /tmp/syms.txt)
    echo "try $t -> $n lines"
    if [ "$n" -gt 1000 ]; then SYM="$t"; break; fi
    head -3 /tmp/syms.err
  fi
done

if [ -z "$SYM" ]; then
  echo "== llvm-nm 不行，退到 python mach-o nlist 解析 =="
  python3 - "$OBJ" > /tmp/syms.txt <<'PY'
import struct, sys
f = open(sys.argv[1], "rb").read()
# 64-bit Mach-O: 找 LC_SYMTAB
magic = struct.unpack_from("<I", f, 0)[0]
assert magic in (0xfeedfacf,), hex(magic)
ncmds = struct.unpack_from("<I", f, 16)[0]
off = 32
symtab = None
texts = []
for _ in range(ncmds):
    cmd, sz = struct.unpack_from("<II", f, off)
    if cmd == 0x2:  # LC_SYMTAB
        symoff, nsyms, stroff, strsize = struct.unpack_from("<IIII", f, off + 8)
        symtab = (symoff, nsyms, stroff, strsize)
    if cmd == 0x19 or cmd == 0x1b:  # LC_SEGMENT_64
        name = f[off+8:off+24].split(b"\0")[0].decode()
        addr, size, fileoff, filesize = struct.unpack_from("<QQQQ", f, off+24)
        maxprot, initprot = struct.unpack_from("<II", f, off+56)
        nsects = struct.unpack_from("<I", f, off+64)[0]
        texts.append((name, addr, size, fileoff, filesize, nsects))
    off += sz
assert symtab
symoff, nsyms, stroff, strsize = symtab
strs = f[stroff:stroff+strsize]
# 建立 sect 映射，用来把 n_value 映射到 vm 地址（内核已按 vm 链接，直接用）
for i in range(nsyms):
    p = symoff + i*16
    n_strx, n_type, n_sect, n_desc = struct.unpack_from("<IBBH", f, p)
    n_value = struct.unpack_from("<Q", f, p+8)[0]
    if n_type & 0x0e == 0x0e:  # N_STAB skip
        continue
    if not (n_type & 0x80) and n_sect != 0:  # external, defined
        end = strs.find(b"\0", n_strx)
        name = strs[n_strx:end].decode(errors="replace")
        if name:
            print("%x t %s" % (n_value, name))
PY
fi
sort -u -k1,1 /tmp/syms.txt | sort > /tmp/syms_sorted.txt
wc -l /tmp/syms_sorted.txt
head -2 /tmp/syms_sorted.txt

echo
echo "== 2. 地址解析 =="
for a in fffffff00772c514 fffffff00772c3b0 fffffff00772c2fc fffffff007adcb18 fffffff007adcb10 fffffff0070d4148 fffffff007a6c6a4; do
  printf '0x%s -> ' "$a"
  python3 - /tmp/syms_sorted.txt "$a" <<'PY'
import sys
t = int(sys.argv[2], 16)
best = None
for line in open(sys.argv[1]):
    p = line.split()
    try:
        a = int(p[0], 16)
    except Exception:
        continue
    if a <= t and (best is None or a > best[0]):
        best = (a, p[-1])
print("NOT-FOUND" if best is None else "%s + 0x%x (@0x%x)" % (best[1], t-best[0], best[0]))
PY
done

echo
echo "== 3. 关注符号 =="
for s in reap_child_locked fork fork1 cloneproc bsd_wait proc_wait4 umi_screen_text umi_scr_puts snprintf vsprintf boot_progress_stage task_terminate_internal thread_is_active; do
  printf '%-24s ' "$s"
  awk -v s="$s" '$3==s {printf "%s ", $1}' /tmp/syms_sorted.txt
  echo
done
echo "== done $(date -u +%FT%TZ)"
