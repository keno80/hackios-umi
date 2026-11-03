#!/usr/bin/env python3
"""Install the corecrypto provider kit into the work tree and export it as a umi-xnu patch."""
import difflib
import os
import subprocess

NL = chr(10)
WORK = '/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/tree/.cache/xnu-work'
PATCHDIR = '/home/unixnu/code/umi-work-pin/devices/umi/patches/umi-xnu'
PATCH = os.path.join(PATCHDIR, 'zzzzzzzzzzzzzzzzzz-umi-crypto-kit.patch')
TAIL = '/mnt/e/Code/HackIos/tools-wsl/umi_crypto_kit_tail.c'
REL = 'libkern/crypto/register_crypto.c'
PE_REL = 'pexpert/arm/pe_init.c'
MARK = '/* ---- umi: corecrypto-backed provider registration ---- */'
SYMBOL = 'umi_crypto_kit_register'
CALL_ANCHOR = 'ConfigureIOKit();'


def read(path):
    with open(path, newline='') as handle:
        return handle.read().splitlines(keepends=True)


def write(path, lines):
    with open(path, 'w', newline='') as handle:
        handle.writelines(lines)


def kit_tail():
    tail = [line.replace('\r\n', '\n') for line in read(TAIL)]
    if not tail:
        raise SystemExit('empty tail')
    if not tail[0].rstrip() == MARK:
        raise SystemExit('tail does not start with the marker')
    return tail


def strip(lines, marker):
    hit = [i for i, line in enumerate(lines) if line.rstrip() == marker]
    if len(hit) > 1:
        raise SystemExit('marker appears %d times, tree is dirty' % len(hit))
    return lines[:hit[0]] if hit else list(lines), bool(hit)


def strip_symbol(lines):
    base = [line for line in lines if SYMBOL not in line
            and 'SHA1 in configureDefaults() needs a crypto provider' not in line]
    return base, len(base) != len(lines)


def install():
    original = {REL: read(os.path.join(WORK, REL)), PE_REL: read(os.path.join(WORK, PE_REL))}

    reg_base, _ = strip(original[REL], MARK)
    mine = reg_base + kit_tail()
    write(os.path.join(WORK, REL), mine)
    reg_new = mine

    pe_base, _ = strip_symbol(original[PE_REL])
    call = '\t/* %s: SHA1 in configureDefaults() needs a crypto provider. */\n' % SYMBOL
    call += '\textern void %s(void);\n' % SYMBOL
    call += '\t%s();\n' % SYMBOL
    out, did_call = [], False
    for line in pe_base:
        if not did_call and line.strip() == CALL_ANCHOR:
            out.extend(call.splitlines(keepends=True))
            did_call = True
        out.append(line)
    if not did_call:
        raise SystemExit('pe_init.c: ConfigureIOKit() call not found')
    write(os.path.join(WORK, PE_REL), out)
    pe_new = out

    return reg_base, reg_new, pe_base, pe_new


def diff(rel, before, after):
    body = difflib.unified_diff(before, after, fromfile='a/' + rel, tofile='b/' + rel,
                                n=3, lineterm=NL)
    lines = [d if d.endswith(NL) else d + NL for d in body]
    if not any(d.startswith('@@') for d in lines):
        raise SystemExit('no hunks produced for ' + rel)
    return lines


def main():
    reg_base, reg_new, pe_base, pe_new = install()
    body = diff(REL, reg_base, reg_new) + diff(PE_REL, pe_base, pe_new)
    write(PATCH, body)
    print('wrote', PATCH, os.path.getsize(PATCH), 'bytes;', len(body), 'patch lines')

    check = subprocess.run(['git', '-C', WORK, 'apply', '--reverse', '--check', PATCH],
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print('reverse-check rc=%d %s' % (check.returncode, check.stdout.decode().strip()))
    return 0 if check.returncode == 0 else 1


raise SystemExit(main())
