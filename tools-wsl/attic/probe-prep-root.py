#!/usr/bin/env python3
import glob, os, subprocess, sys

OUT = open('/mnt/e/Code/HackIos/out/probes/prep-root.txt', 'w')
def w(*a):
    print(*a, file=OUT)

R = '/home/unixnu/code/umi-work-pin'
w('== head of devices/umi/scripts/prepare-xnu-source.py ==')
w(open(os.path.join(R, 'devices/umi/scripts/prepare-xnu-source.py')).read()[:2200])
w('== tree patches dirs ==')
for p in sorted(glob.glob(R + '/out/umi-xnu/umi/tree/patches/*')):
    w(p, '<- symlink' if os.path.islink(p) else '')
w('== devices/umi/patches listing ==')
for p in sorted(glob.glob(R + '/devices/umi/patches/*')):
    w(p, '<- symlink' if os.path.islink(p) else '')
w('== build status json ==')
for p in glob.glob(R + '/out/**/source-build-status.json', recursive=True)[:6]:
    w(p)
    w(open(p).read()[:900])
OUT.close()
