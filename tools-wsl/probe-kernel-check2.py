#!/usr/bin/env python3
import glob
import os
import subprocess

OUT = open('/mnt/e/Code/HackIos/out/probes/kernel-check2.txt', 'w')
WS = '/home/unixnu/code/umi-work-pin'
TREE = WS + '/out/umi-xnu/umi/tree'
KER = WS + '/out/umi-xnu/umi/kernel/source-kernel.macho'


def w(*a):
    print(*a, file=OUT)


w('== tail present in rebuilt source? ==')
vc = TREE + '/.cache/xnu-work/osfmk/console/video_console.c'
w('video_console.c lines=%d' % sum(1 for _ in open(vc, errors='replace')))
w('grep UMI_SCR_SCALE ->', subprocess.run(['grep', '-c', 'UMI_SCR_SCALE', vc],
                                          stdout=subprocess.PIPE).stdout.decode().strip())
for f in ('osfmk/arm/arm_init.c', 'osfmk/kern/startup.c', 'osfmk/kern/debug.c'):
    p = TREE + '/.cache/xnu-work/' + f
    w('%s umi_screen refs=%s' % (f, subprocess.run(['grep', '-c', 'umi_screen', p],
                                                   stdout=subprocess.PIPE).stdout.decode().strip()))

w('== object files ==')
for pat in ('osfmk/DEVELOPMENT/video_console.o', 'osfmk/DEVELOPMENT/arm_init.o', 'osfmk/DEVELOPMENT/startup.o'):
    hits = glob.glob(TREE + '/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/' + pat)
    for h in hits:
        w(h, os.path.getsize(h))
    if not hits:
        w('missing', pat)
vo = TREE + '/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/osfmk/DEVELOPMENT/video_console.o'
if os.path.exists(vo):
    d = open(vo, 'rb').read()
    w('video_console.o has UMI SCREEN literal:', b'UMI SCREEN fb=' in d)
    w('video_console.o has umi_screen_mark:', b'umi_screen_mark' in d)

w('== macho head bytes ==')
d = open(KER, 'rb').read()
w('first 16 bytes', d[:16].hex())
w('contains b"UMI":', d.count(b'UMI'))
idx = d.find(b'UMI')
if idx >= 0:
    w('sample', d[idx - 40:idx + 60])
w('contains "video_console":', d.count(b'video_console'))
w('contains "kprintf":', d.count(b'kprintf'))
OUT.close()
