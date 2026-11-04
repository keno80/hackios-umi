#!/usr/bin/env python3
import sys
from pathlib import Path
sys.path.insert(0, "/home/unixnu/code/umi-work-pin/out/umi/adtdev/scripts")
from umi_adt import decode

adt = Path("/home/unixnu/code/umi-work-pin/out/umi/xnu/stage/Payloads/kernel.macho.adt")
tree = decode(adt.read_bytes())


def cells(v):
    if isinstance(v, (bytes, bytearray)):
        return v.hex()
    return str(v)


for node in tree.walk() if hasattr(tree, "walk") else []:
    pass

print("root children:", sorted(tree.at("/").children.keys()) if hasattr(tree.at("/"), "children") else "?")
for name in ("/", "/chosen", "/memory-map", "/cpus", "/gic", "/timer"):
    try:
        node = tree.at(name)
    except Exception as error:
        print(name, "->", error)
        continue
    props = getattr(node, "properties", {})
    print(f"--- {name} ({len(props)} props, {len(getattr(node, 'children', {}))} children)")
    for key in sorted(props):
        value = props[key]
        text = cells(value)
        if len(text) > 96:
            text = text[:96] + "..."
        print(f"    {key} = {text}")
