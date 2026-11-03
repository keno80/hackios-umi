#!/usr/bin/env python3
import subprocess

OUT = open('/mnt/e/Code/HackIos/out/kernel-check4.txt', 'w')
VO = '/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/osfmk/DEVELOPMENT/video_console.o'
AI = '/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/build/xnu/ios-obj/DEVELOPMENT_ARM64_BCM2837/osfmk/DEVELOPMENT/arm_init.o'
KER = '/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho'


def w(*a):
    print(*a, file=OUT)


def run(args, label, limit=4000):
    r = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    w('== %s (rc=%d) ==' % (label, r.returncode))
    w(r.stdout.decode(errors='replace')[:limit])


run(['llvm-nm', VO], 'llvm-nm video_console.o')
run(['llvm-objdump', '-s', '-j', '__cstring', VO], 'cstring video_console.o')
run(['llvm-nm', '-u', AI], 'llvm-nm -u arm_init.o')
run(['llvm-objdump', '-h', KER], 'macho headers', 6000)
OUT.close()
