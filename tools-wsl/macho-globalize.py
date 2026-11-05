#!/usr/bin/env python3
"""Give a thin 64-bit Mach-O object what `llvm-objcopy --globalize-symbol` would.

Ubuntu's LLVM 18.1.3 llvm-objcopy answers "option is not supported for MachO" for
--globalize-symbol (verified per option in out/probes/u204-objcopy-capability.txt),
while devices/umi/scripts/build-umi-platform-power.py:131 and
devices/umi/bringup/tools/build_umi_data_display.py:114 both need it to keep the
static-initializer symbol reachable after __DATA,__mod_init_func is stripped.
"""
import argparse
import struct
import sys
from pathlib import Path

MH_MAGIC_64 = 0xFEEDFACF
LC_SYMTAB = 0x2
N_STAB = 0xE0
N_PEXT = 0x10
N_EXT = 0x01


def symtab(data):
    if struct.unpack_from("<I", data, 0)[0] != MH_MAGIC_64:
        raise SystemExit("macho-globalize: not a little-endian 64-bit Mach-O object")
    ncmds = struct.unpack_from("<I", data, 16)[0]
    offset = 32
    for _ in range(ncmds):
        command, command_size = struct.unpack_from("<2I", data, offset)
        if command == LC_SYMTAB:
            symbol_offset, count, strings, string_size = struct.unpack_from("<4I", data, offset + 8)
            if command_size < 24:
                raise SystemExit("macho-globalize: short LC_SYMTAB")
            if symbol_offset + count * 16 > len(data) or strings + string_size > len(data):
                raise SystemExit("macho-globalize: LC_SYMTAB runs past the file")
            return symbol_offset, count, strings, string_size
        if command_size == 0:
            raise SystemExit("macho-globalize: zero-sized load command")
        offset += command_size
    raise SystemExit("macho-globalize: object has no LC_SYMTAB")


def symbol_name(data, strings, string_size, index):
    start = strings + index
    if start >= strings + string_size:
        raise SystemExit("macho-globalize: strx runs past the string table")
    end = data.find(b"\0", start, strings + string_size)
    if end < 0:
        raise SystemExit("macho-globalize: unterminated string table entry")
    return data[start:end].decode()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--symbol", required=True)
    arguments = parser.parse_args()

    data = bytearray(arguments.input.read_bytes())
    symbol_offset, count, strings, string_size = symtab(data)
    hits = []
    for entry in range(count):
        at = symbol_offset + entry * 16
        index, kind = struct.unpack_from("<IB", data, at)
        if kind & N_STAB:
            continue
        if symbol_name(data, strings, string_size, index) == arguments.symbol:
            hits.append((at, kind))
    if not hits:
        raise SystemExit(f"macho-globalize: no symbol table entry named {arguments.symbol}")
    if len(hits) != 1:
        raise SystemExit(f"macho-globalize: {arguments.symbol} appears {len(hits)} times")
    at, kind = hits[0]
    if kind & N_EXT and not kind & N_PEXT:
        print(f"macho-globalize: {arguments.symbol} is already global")
        return 0
    before = bytes(data)
    data[at + 4] = (kind & ~N_PEXT) | N_EXT
    if bytes(data) == before:
        raise SystemExit("macho-globalize: nothing changed")
    if sum(1 for a, b in zip(before, data) if a != b) != 1:
        raise SystemExit("macho-globalize: more than one byte changed")
    arguments.input.write_bytes(bytes(data))
    print(f"macho-globalize: {arguments.symbol} {kind:#04x} -> {data[at + 4]:#04x}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
