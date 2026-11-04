#!/usr/bin/env python3
"""Give the umi QEMU runner a mockfs fake-root initrd path.

--mockfs-initrd publishes an ordinary file as the loader-owned RAMDisk
(/chosen/memory-map RAMDisk), sets the XNU entry initrd, and prepends rd=md0 so
IOFindBSDRoot() roots on md0 and mockfs_mountroot() can claim it.
"""
import glob
import py_compile
import sys

ARG_OLD = '''    p.add_argument("--data-ramdisk", type=Path,
                   help="the same original packed APFS Data input used by the source build")
'''
ARG_NEW = ARG_OLD + '''    p.add_argument("--mockfs-initrd", type=Path,
                   help="publish this file as the loader-owned RAMDisk so XNU roots on the mockfs fixture")
'''

GUARD_OLD = '''    a = p.parse_args()
    if a.systemos_volume and not a.root_volume:
'''
GUARD_NEW = '''    a = p.parse_args()
    if a.mockfs_initrd and a.data_ramdisk:
        p.error("the mockfs root and the packed Data seed share one RAMDisk binding; select one")
    if a.systemos_volume and not a.root_volume:
'''

COPY_OLD = '''        shutil.copyfile(seed, payload / "kernel.macho.ramdisk")
    trust_sha = None
'''
COPY_NEW = '''        shutil.copyfile(seed, payload / "kernel.macho.ramdisk")
    mockfs_input = None
    if a.mockfs_initrd:
        mockfs_input = a.mockfs_initrd.resolve()
        if not mockfs_input.is_file() or mockfs_input.stat().st_size < 4096:
            p.error("the mockfs initrd must be a regular file of at least one page")
        shutil.copyfile(mockfs_input, payload / "launchd.macho")
    boot_args = ("rd=md0 " + a.args) if mockfs_input else a.args
    trust_sha = None
'''

DT_OLD = '''        *(["--trust-cache"] if a.trust_cache else []),
        *(["--data-ramdisk"] if data_input else []),
'''
DT_NEW = '''        *(["--trust-cache"] if a.trust_cache else []),
        *(["--data-ramdisk"] if data_input else []),
        *(["--ramdisk"] if mockfs_input else []),
'''

CFG_OLD = """        ('initrd = \"Payloads/kernel.macho.ramdisk\"\\n' if data_input else '') +
        f'args = \"{a.args}\"\\n')
"""
CFG_NEW = """        ('initrd = "Payloads/kernel.macho.ramdisk"\\n' if data_input else
         ('initrd = "Payloads/launchd.macho"\\n' if mockfs_input else '')) +
        f'args = "{boot_args}"\\n')
"""

PROV_OLD = '''        "boot_args": a.args, "trace_symbols": {n: symbol(n) for n in a.trace},
'''
PROV_NEW = '''        "boot_args": boot_args, "trace_symbols": {n: symbol(n) for n in a.trace},
'''

PROV2_OLD = '''        "data_input": data_input,
'''
PROV2_NEW = '''        "data_input": data_input,
        "mockfs_initrd": None if mockfs_input is None else
            {"path": str(mockfs_input), "sha256": digest(mockfs_input)},
'''

TARGETS = sorted(set(glob.glob("/home/unixnu/code/*/tools/run_umi_qemu.py") +
                     glob.glob("/home/unixnu/code/*/bringup/tools/run_umi_qemu.py") +
                     glob.glob("/home/unixnu/code/*/devices/umi/tools/run_umi_qemu.py")))

edits = (ARG_OLD, ARG_NEW, GUARD_OLD, GUARD_NEW, COPY_OLD, COPY_NEW,
         DT_OLD, DT_NEW, CFG_OLD, CFG_NEW, PROV_OLD, PROV_NEW,
         PROV2_OLD, PROV2_NEW)

if not TARGETS:
    raise SystemExit("no run_umi_qemu.py found")
report = {}
for path in TARGETS:
    text = open(path, encoding="utf-8").read()
    if "--mockfs-initrd" in text:
        report[path] = "already patched"
        continue
    for index in range(0, len(edits), 2):
        old, new = edits[index], edits[index + 1]
        if text.count(old) != 1:
            raise SystemExit("%s: anchor %d matched %d times" % (path, index // 2, text.count(old)))
        text = text.replace(old, new)
    open(path, "w", encoding="utf-8").write(text)
    py_compile.compile(path, doraise=True)
    report[path] = "patched and compiles"
print(sys.version.split()[0])
for path, state in report.items():
    print(path, "->", state)
