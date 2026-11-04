#!/usr/bin/env python3
"""把上游 qemu-entry/gdb-stop.py 复制成带 SCTLR_EL1 别名的观测件。

本机 QEMU 8.2.2 在 system-registers.xml 里把 EL1 系统控制寄存器命名为 SCTLR
（GDB 传统名），上游观测件按精确名 SCTLR_EL1 匹配，于是 system_registers
永远缺这一键——本仓 20+ 个 check 脚本都要它。这里只做改名，不改读法。
"""
import argparse
import sys
from pathlib import Path

SOURCE = Path("/home/unixnu/code/UniXNU-pin/scripts/qemu-entry/gdb-stop.py")

WANTED_ANCHOR = ("                wanted = {'TCR_EL1', 'TTBR0_EL1', 'TTBR1_EL1', 'SCTLR_EL1', 'CNTFRQ_EL0',\n"
                 "                          'ESR_EL1', 'FAR_EL1', 'ELR_EL1', 'SPSR_EL1', 'ID_AA64MMFR1_EL1', "
                 "'ID_AA64MMFR0_EL1', 'MIDR_EL1'}\n")
STORE_ANCHOR = ("                            report['system_registers'][register.attrib['name']] = hex(value)\n")
IMPORT_ANCHOR = "\nimport argparse\n"

WANTED_PATCH = WANTED_ANCHOR.rstrip("\n")[:-1] + ", 'SCTLR', 'ATCR_EL1'}\n"
ALIAS_LINE = ("                QEMU_SCTLR_EL1_ALIAS = {'SCTLR': 'SCTLR_EL1'}\n"
              "                report['system_registers'] = {}\n")
STORE_PATCH = (
    "                            _name = register.attrib['name']\n"
    "                            report['system_registers'][_name] = hex(value)\n"
    "                            if _name in QEMU_SCTLR_EL1_ALIAS:\n"
    "                                report['system_registers'][QEMU_SCTLR_EL1_ALIAS[_name]] = hex(value)\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    content = SOURCE.read_text()
    for name, anchor in (("wanted", WANTED_ANCHOR), ("store", STORE_ANCHOR), ("import", IMPORT_ANCHOR)):
        if content.count(anchor) != 1:
            raise SystemExit(f"anchor {name} matched {content.count(anchor)} times in {SOURCE}")
    # 别名键必须在 report['system_registers'] = {} 之后、循环之前定义
    content = content.replace("                report['system_registers'] = {}\n", ALIAS_LINE, 1)
    content = content.replace(WANTED_ANCHOR, WANTED_PATCH, 1)
    content = content.replace(STORE_ANCHOR, STORE_PATCH, 1)
    # 观测件被复制到别处后，from gdb_packets import Packets 仍要吃上游同目录的模块
    content = content.replace(IMPORT_ANCHOR,
                              "\nimport argparse\nimport sys\nsys.path.insert(0, " + repr(str(SOURCE.parent)) + ")\n",
                              1)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(content)
    import hashlib
    print(f"observer={args.output} sha256={hashlib.sha256(args.output.read_bytes()).hexdigest()}")
    print("source-sha256=" + hashlib.sha256(SOURCE.read_bytes()).hexdigest())
    return 0


if __name__ == "__main__":
    sys.exit(main())
