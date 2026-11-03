#!/usr/bin/env python3
"""Guard the three AMFI entitlement helpers against the unregistered KPI and export it as a umi-xnu patch."""
import difflib
import os
import subprocess

NL = chr(10)
WORK = '/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work'
PATCHDIR = '/home/unixnu/code/umi-work-pin/devices/umi/patches/umi-xnu'
PATCH = os.path.join(PATCHDIR, 'zzzzzzzzzzzzzzzzzzz-umi-amfi-guard.patch')
REL = 'iokit/bsddev/IOKitBSDInit.cpp'
MARK = '\t/* umi: no AMFI KPI is registered, so every query means "no entitlement". */'
GUARD_NULL = MARK + NL + '\tif (amfi == NULL) {\n\t\treturn NULL;\n\t}\n'
GUARD_FALSE = MARK + NL + '\tif (amfi == NULL) {\n\t\treturn false;\n\t}\n'
PROC_LINE = '\tproc_t proc = (proc_t)get_bsdtask_info(task);\n'
SITES = (('queryEntitlementStringWithProc', GUARD_FALSE),
         ('queryEntitlementBooleanWithProc', GUARD_FALSE),
         ('copyEntitlementAsOSObjectWithProc', GUARD_NULL))


def read(path):
    with open(path, newline='') as handle:
        return handle.read().splitlines(keepends=True)


def write(path, lines):
    with open(path, 'w', newline='') as handle:
        handle.writelines(lines)


def strip_guard(lines):
    out, i, removed = [], 0, 0
    while i < len(lines):
        if lines[i].rstrip() == MARK:
            i += 4
            removed += 1
            continue
        out.append(lines[i])
        i += 1
    return out, removed


def install():
    original = read(os.path.join(WORK, REL))
    base, removed = strip_guard(original)
    if any(line.rstrip() == MARK for line in base):
        raise SystemExit('guard block survived stripping; tree is dirty')
    out, inserted = [], []
    for index, line in enumerate(base):
        out.append(line)
        for name, guard in SITES:
            if name in line and 'amfi->OSEntitlements.' in line:
                spot = max(i for i, prev in enumerate(out) if prev == PROC_LINE)
                out[spot:spot] = guard.splitlines(keepends=True)
                inserted.append(name)
    if len(inserted) != len(SITES):
        raise SystemExit('expected 3 entitlement sites, found %r' % (inserted,))
    write(os.path.join(WORK, REL), out)
    return base, out, removed, inserted


def main():
    base, patched, removed, inserted = install()
    body = [d if d.endswith(NL) else d + NL for d in
            difflib.unified_diff(base, patched, fromfile='a/' + REL, tofile='b/' + REL,
                                 n=3, lineterm=NL)]
    if not any(d.startswith('@@') for d in body):
        raise SystemExit('no hunks produced')
    write(PATCH, body)
    print('wrote', PATCH, os.path.getsize(PATCH), 'bytes;', len(body), 'patch lines;',
          'replaced %d previous guard(s)' % removed, '; sites:', inserted)

    check = subprocess.run(['git', '-C', WORK, 'apply', '--reverse', '--check', PATCH],
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print('reverse-check rc=%d %s' % (check.returncode, check.stdout.decode().strip()))
    return 0 if check.returncode == 0 else 1


raise SystemExit(main())
