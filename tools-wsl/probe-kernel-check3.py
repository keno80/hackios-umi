#!/usr/bin/env python3
import os
import subprocess

OUT = open('/mnt/e/Code/HackIos/out/probes/kernel-check3.txt', 'w')
WS = '/home/unixnu/code/umi-work-pin'
TREE = WS + '/out/umi-xnu/umi/tree'
KER = WS + '/out/umi-xnu/umi/kernel/source-kernel.macho'
VO = TREE + '/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/osfmk/DEVELOPMENT/video_console.o'


def w(*a):
    print(*a, file=OUT)


for name, path in (('macho', KER), ('video_console.o', VO)):
    d = open(path, 'rb').read()
    w('%s size=%d mtime=%d' % (name, len(d), os.path.getmtime(path)))
    for needle in (b'SCREEN', b'PANIC', b'fb=', b'UMI', b'umi_scr_', b'umi_screen_halt', b'iso_font'):
        w('   %-16s %d' % (needle.decode(), d.count(needle)))

w('== strings | grep -i umi (macho) ==')
r = subprocess.run('strings -a %s | grep -i "umi" | head -20' % KER, shell=True,
                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
w(r.stdout.decode(errors='replace'))
w('== nm -a video_console.o | grep umi ==')
r = subprocess.run('nm %s | grep -i umi | head -30' % VO, shell=True,
                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
w(r.stdout.decode(errors='replace'))
w('== otool/size sections ==')
for tool in ('llvm-objdump', 'objdump'):
    p = subprocess.run(['which', tool], stdout=subprocess.PIPE).stdout.decode().strip()
    if p:
        w('found', p)
        r = subprocess.run([p, '-h', VO], stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        w(r.stdout.decode(errors='replace')[:1500])
        break
OUT.close()
