#!/usr/bin/env python3
"""Symbolicate a gdb-stop.json snapshot against the kernel Mach-O nm table."""
import bisect
import json
import subprocess
import sys
from pathlib import Path

run = Path(sys.argv[1])
kernel = Path(sys.argv[2])
stop = json.loads((run / "gdb-stop.json").read_text())

addrs, names = [], []
for line in subprocess.check_output(["xcrun", "nm", "-n", str(kernel)], text=True).splitlines():
    f = line.split()
    if len(f) == 3:
        a = int(f[0], 16)
        if a and (not addrs or a >= addrs[-1]):
            addrs.append(a)
            names.append(f[2])


def near(hexstr):
    if not hexstr:
        return "?"
    a = int(hexstr, 0)
    i = bisect.bisect_right(addrs, a) - 1
    if i < 0:
        return f"{hexstr} <最低符号>"
    return f"{names[i]} +{a - addrs[i]:#x}  ({hexstr})"


print(f"== 符号表 {len(addrs)} 项  run={run.name}")
print(f"timeout={stop.get('bounded_timeout_interrupted')} stop={stop.get('stop')} "
      f"skipped_hits={stop.get('skipped_target_hits')}")
print("pc   ->", near(stop.get("pc")))
print("lr   ->", near(stop.get("x30")))
print("ELR  ->", near(stop.get("system_registers", {}).get("ELR_EL1")))
print("-- frame_chain --")
for i, fr in enumerate(stop.get("frame_chain", [])):
    print(f" f{i:02d} fp={fr['fp']} lr-> {near(fr['lr'])}")
print("-- 关键寄存器 --")
for r in ("x0", "x1", "x8", "x19", "x20", "x21", "x25", "x29"):
    print(f" {r}={stop.get(r)}")
print("ESR_EL1=%s FAR_EL1=%s" % (stop.get("system_registers", {}).get("ESR_EL1"),
                                 stop.get("system_registers", {}).get("FAR_EL1")))
print("-- stderr --")
err = run / "gdb-stderr.log"
if err.exists():
    print(err.read_text()[-500:])
