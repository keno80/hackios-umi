#!/bin/bash
# T 步实施前的事实核对（台阶1：塞真 Apple 件进假根 exec）
#   1) mockfs 两个 fsnode 在容器模式下叫什么名（init 要 exec 的路径必须命中其一）；
#   2) 我们内核里 PID 1 的 exec 路径与 'INIT try' 探针现场；
#   3) QEMU 通路 run_umi_qemu.py 对 --mockfs-initrd 有没有尺寸/对齐窗口；
#   4) 真件头 12 字节是否满足上游断言 (0xfeedfacf, 0x100000c, 0)；
#   5) 上游要的原版 static trustcache 在本机是否存在。
set -u
exec > /mnt/e/Code/HackIos/out/probes/t1-facts.txt 2>&1
T=/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree
U=/home/unixnu/code/UniXNU-main
EL=/home/unixnu/code/umi-work-pin/out/umi-xnu/apple-el0

echo "== 1. mockfs_fsnode.c 里的名字表（ROOT/DEV/FILE/TEST_FILE）=="
grep -n -B6 -A24 'MOCKFS_TEST_FILE' "$T/bsd/miscfs/mockfs/mockfs_fsnode.c" | head -80
echo
echo "-- mockfs_fsnode.h 枚举 --"
sed -n '1,80p' "$T/bsd/miscfs/mockfs/mockfs_fsnode.h" 2>/dev/null | grep -n -A12 'enum mockfs_type'
echo
echo "== 2. 内核里 exec init 的路径与探针现场 =="
grep -rn 'INIT try' "$T" 2>/dev/null | grep -v Binary | head -5
echo "-- 命中文件里的 exec 上下文 --"
F=$(grep -rl 'INIT try' "$T" 2>/dev/null | grep -v Binary | head -1)
echo "file=$F"
[ -n "$F" ] && grep -n -B12 -A6 'INIT try' "$F" | head -60
echo "-- 源码里 init 程序路径默认值 --"
grep -rn '"/sbin/launchd"\|sbin/launchd' "$T/bsd/init/bootstrap.c" "$T/bsd/kern/kern_exec.c" 2>/dev/null | head -10
grep -rn 'unixnu_el0_init_paths\|init_program\|UNIXNU_INIT' "$T" 2>/dev/null | grep -v Binary | head -20

echo
echo "== 3. QEMU 工具对 mockfs initrd 的处理 =="
RP=$(find /home/unixnu/code/umi-work-pin /home/unixnu/code/UniXNU-main -maxdepth 4 -name run_umi_qemu.py 2>/dev/null | head -1)
echo "run_umi_qemu.py = $RP"
grep -n -B3 -A18 'mockfs_initrd\|mockfs-initrd' "$RP" 2>/dev/null | head -90
echo "-- 尺寸相关约束 --"
grep -n 'initrd\|ramdisk\|md0\|1024 \* 1024\|MiB\|mib' "$RP" 2>/dev/null | head -30

echo
echo "== 4. 真件头 12 字节 + 尺寸 =="
python3 - "$EL" <<'PY'
import struct, sys, pathlib
el = pathlib.Path(sys.argv[1])
for n in ('launchd', 'dyld'):
    p = el / n
    d = p.read_bytes()
    print(f"{n}: {len(d):,} B  hdr={struct.unpack_from('<3I', d)}  "
          f"mh_magic=0x{struct.unpack_from('<I', d)[0]:08x}")
PY

echo
echo "== 5. 上游原版 static trustcache 在本机 =="
ls -l "$U/.cache/firmware/target-volumes/" 2>&1 | head
find /home/unixnu/code -maxdepth 6 -name 'static-trustcache.bin' 2>/dev/null | head

echo
echo "== 6. 现有走查件是 legacy 裸 Mach-O 还是容器 =="
python3 - <<'PY'
import struct, pathlib
p = pathlib.Path('/mnt/e/Code/HackIos/out/fixtures/launchd-walk.macho')
d = p.read_bytes()[:64]
print('size', p.stat().st_size, 'first8', d[:8], 'mh=0x%08x' % struct.unpack_from('<I', d)[0])
print('kind:', 'N4KROOT 容器' if d[:7] == b'N4KROOT' else 'legacy 裸 Mach-O')
PY
echo "== done $(date -u +%FT%TZ)"
