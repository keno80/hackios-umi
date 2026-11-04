#!/usr/bin/env python3
"""Give run_umi_qemu.py a bounded EL0 read path so the native fixture's result globals can be observed."""
import py_compile
import sys

ARG_OLD = '''    p.add_argument("--read-address", action="append", default=[], metavar="HEX_ADDRESS:HEX_BYTES",
                   help="observe exact addresses derived by a component ABI audit")
'''
ARG_NEW = ARG_OLD + '''    p.add_argument("--read-user-address", action="append", default=[], metavar="HEX_ADDRESS:HEX_BYTES",
                   help="observe a bounded EL0 address, such as a fixture result global")
'''
LOOP_OLD = '''        command += ["--read-memory",f"{address:x}:{size:x}"]
'''
LOOP_NEW = LOOP_OLD + '''    for request in a.read_user_address:
        address,size=(int(v,16) for v in request.split(":"))
        if not 0<address<0xffff000000000000 or not 0<size<=4096:
            p.error("EL0 observation must be a bounded user address")
        command += ["--read-memory",f"{address:x}:{size:x}"]
'''
TARGETS = ['/home/unixnu/code/UniXNU-umi/bringup/tools/run_umi_qemu.py',
           '/home/unixnu/code/umi-work-pin/tools/run_umi_qemu.py',
           '/home/unixnu/code/umi-work/tools/run_umi_qemu.py']

for path in TARGETS:
    try:
        text = open(path).read()
    except OSError:
        print('skip (missing)', path)
        continue
    if '--read-user-address' in text:
        print('already patched', path)
        continue
    for old, new in ((ARG_OLD, ARG_NEW), (LOOP_OLD, LOOP_NEW)):
        if text.count(old) != 1:
            raise SystemExit('%s: anchor count %d for %r' % (path, text.count(old), old[:48]))
        text = text.replace(old, new)
    open(path, 'w').write(text)
    py_compile.compile(path, doraise=True)
    print('patched and compiles', path)
