#!/usr/bin/env python3
import subprocess

OUT = open('/mnt/e/Code/HackIos/out/probes/kernel-check5.txt', 'w')
VO = '/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/osfmk/DEVELOPMENT/video_console.o'
KER = '/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho'


def w(*a):
    print(*a, file=OUT)


def run(args, label, limit=6000):
    r = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    w('== %s (rc=%d) ==' % (label, r.returncode))
    w(r.stdout.decode(errors='replace')[:limit])


run('nm %s | grep -i umi' % VO, 'nm video_console.o (gnu nm)')
run('llvm-nm %s | grep -i umi' % VO, 'llvm-nm video_console.o')
run('strings -a %s | grep -i -E "umi |screen|panic|fb=|row=|geom=" | head -30' % VO, 'strings video_console.o')
run('llvm-objdump -d %s | sed -n "/_umi_scr_setup:/,/ret/p" | head -60' % VO, 'disasm umi_scr_setup')
run('llvm-nm %s | grep -i -E "umi_screen|umi_scr" | head -30' % KER, 'llvm-nm kernel macho')
OUT.close()
