#!/usr/bin/env python3
import glob
import json
import os
import subprocess

OUT = open('/mnt/e/Code/HackIos/out/probes/buildstate.txt', 'w')
R = '/home/unixnu/code/umi-work-pin'


def w(*a):
    print(*a, file=OUT)


w('== newest build log dirs ==')
logs = sorted(glob.glob(R + '/out/umi-xnu/umi/logs/*'), key=os.path.getmtime)
for p in logs[-6:]:
    w(p, subprocess.check_output(['ls', p]).decode().count('\n'), 'files')
w('== newest status json full ==')
for p in sorted(glob.glob(R + '/out/umi-xnu/umi/source-build-status.json')):
    w(open(p).read())
w('== kernel macho candidates by mtime ==')
for p in glob.glob(R + '/out/umi-xnu/umi/tree/**/mach.development*', recursive=True) + \
         glob.glob(R + '/out/umi-xnu/umi/tree/**/kernel.macho', recursive=True) + \
         glob.glob(R + '/out/umi-xnu/umi/tree/.cache/xnu-work/build/**/*macho*', recursive=True):
    st = os.stat(p)
    w(p, st.st_size, st.st_mtime)
w('== build-xnu-payload.py ==')
w(open('/mnt/e/Code/HackIos/tools-wsl/build-xnu-payload.py').read())
OUT.close()
