#!/bin/bash
# N 步之三：解码 run-25 的 _walk/_nz 两页，并读 fork 子进程返回值的落地代码。
# 现场疑点：屏上 WAIT4 A none pid=2 —— 打 wait4 的是子进程自己，说明子进程没走 _child 分支，
# 也就是 fork 回到子进程时 x0 不是 0（fixture 用 cbz x0,_child 判父子）。
# _walk 基址 0x100004040，[8]=fork 返回值，[9]=wait4 返回值；_nz 基址 0x1000040c0。
set -uo pipefail
OUT=/mnt/e/Code/HackIos/out/probes/n16-decode-walk.txt
: > "$OUT"
exec >>"$OUT" 2>&1

WS=/home/unixnu/code/umi-work-pin
X=$WS/out/umi-xnu/umi/tree/.cache/xnu-work
RUN=$WS/out/umi-qemu/run-25-fork
FX=/mnt/e/Code/HackIos/out/fixtures/launchd-walk.macho
TC=${UNIXNU_TOOLCHAIN:-/opt/unixnu-linux}

echo "== 1. 解码两页（小端 u64）=="
python3 - <<'PY'
import json, struct
r = json.load(open('/home/unixnu/code/umi-work-pin/out/umi-qemu/run-25-fork/gdb-stop.json'))
mem = r.get('memory', {})
names = ['getppid','gettimeofday','getrusage','open /nonexistent','open /launchd',
         'read','close','stat64 /dev','FORK','WAIT4','?10','?11']
for addr in ('100004040:96', '1000040c0:96'):
    h = mem.get(addr)
    print('---', addr, 'len', (len(h)//2 if h else 0))
    if not h:
        print('  NO-DATA')
        continue
    b = bytes.fromhex(h)
    for i in range(0, len(b) - 7, 8):
        v = struct.unpack('<Q', b[i:i+8])[0]
        tag = names[i // 8] if i // 8 < len(names) else '?'
        print('  [%2d] +0x%02x %-18s = %s (%d)' % (i // 8, i, tag, hex(v), v))
print('pc =', r.get('pc'), 'x0 =', r.get('x0'))
PY

echo
echo "== 2. fixture 符号：确认 _walk/_nz/_child/_checkpoint 的地址 =="
for T in "$TC/llvm/bin/llvm-nm" "$TC/CommandLineTools/usr/bin/nm"; do
  [ -x "$T" ] && { echo "try $T"; "$T" -n "$FX" 2>/dev/null | grep -iE '_(walk|nz|child|checkpoint|start|results)$' && break; }
done

echo
echo "== 3. 0x100003f80..0x100004040 的反汇编（走查尾段）=="
for T in "$TC/llvm/bin/llvm-objdump" /usr/bin/llvm-objdump; do
  [ -x "$T" ] && { echo "try $T"; "$T" -d --start-address=0x100003f80 --stop-address=0x100004040 "$FX" 2>&1 | tail -40; break; }
done

echo
echo "== 4. thread_set_child 全文 =="
F=$(grep -rl '^thread_set_child' "$X/osfmk" 2>/dev/null | head -1)
echo "FILE=$F"
L=$(grep -n '^thread_set_child' "$F" | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "$((L-6)),$((L+40))p" "$F"

echo
echo "== 5. machine_set_child / thread_set_child 的调用点 =="
grep -rn 'machine_set_child\|thread_set_child' "$X/bsd" "$X/osfmk" 2>/dev/null | grep -v '\.o:' | head -12

echo
echo "== 6. set_user_saved_state_reg 定义 =="
grep -rn 'define set_user_saved_state_reg\|set_user_saved_state_reg(' "$X/osfmk/arm/save_state.h" 2>/dev/null | head -8
echo done
