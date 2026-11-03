#!/usr/bin/env python3
"""为本机 8+256 生成 umi 硬件画像沙箱并干跑 ADT。

只读仓内文件；产物全部落在 out/umi/adtdev 与 out/umi/xnu。
沙箱结构让 make-umi-adt.py 的 hardware_path() 命中 package/umi-hardware.json。
"""
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path("/home/unixnu/code/umi-work-pin")
DEV = ROOT / "devices/umi"
SANDBOX = ROOT / "out/umi/adtdev"
OUT = ROOT / "out/umi/xnu"
DTB = ROOT / "out/umi/dtb/umi-running.dtb"

# 本机 running.dtb 的 /memory reg（#16 真机读数一致）
BANKS = [
    (0x80000000, 0x3BB00000),
    (0xC0000000, 0xC0000000),
    (0x180000000, 0x100000000),
]
DRAM = sum(size for _, size in BANKS)


def main():
    src = json.loads((DEV / "package/umi-hardware.json").read_text())
    dtb_sha = hashlib.sha256(DTB.read_bytes()).hexdigest()

    hw = dict(src)
    hw["memory_banks"] = [{"base": base, "size": size} for base, size in BANKS]
    hw["sources"] = {
        "running_dtb_sha256": dtb_sha,
        "evidence_snapshot": "20261103T045237Z",
        "measured_by": "UmiMemoryDiag on this unit, 2026-11-03 (fastboot boot, zero writes)",
        "so_fields_unchanged": "cpus, gic, timer, framebuffer, psci, platform_chip_id",
        "derived_from": "devices/umi/package/umi-hardware.json (12 GiB handset)",
    }

    scripts = SANDBOX / "scripts"
    package = SANDBOX / "package"
    shutil.rmtree(SANDBOX, ignore_errors=True)
    scripts.mkdir(parents=True)
    package.mkdir(parents=True)
    for name in ("make-umi-adt.py", "umi_adt.py"):
        shutil.copy2(DEV / "scripts" / name, scripts / name)
    (package / "umi-hardware.json").write_text(json.dumps(hw, indent=2) + "\n")

    # 平台种子：本机唯一、可复现，取自本机 running.dtb 摘要前 8 字节
    seed = dtb_sha[:16]

    adt = OUT / "stage/Payloads/kernel.macho.adt"
    adt.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        sys.executable, str(scripts / "make-umi-adt.py"),
        "--output", str(adt),
        "--dram-size", hex(DRAM),
        "--owned-memory-size", "0x10000000",
        "--chip-id", "0x164",
        "--cpu-regs", "0,0x100,0x200,0x300,0x400,0x500,0x600,0x700",
        "--psci-method", "smc",
        "--unique-chip-id", seed,
    ]
    print("dram =", hex(DRAM), f"({DRAM / 2**30:.2f} GiB)  seed = 0x{seed}")
    result = subprocess.run(cmd, cwd=SANDBOX, capture_output=True, text=True)
    print("rc =", result.returncode)
    print(result.stdout.strip())
    if result.stderr.strip():
        print("stderr:", result.stderr.strip()[:800])
    if result.returncode != 0:
        return 1

    report = json.loads(adt.with_name(adt.name + ".json").read_text())
    keep = ("adt_sha256", "bytes", "cpus", "gic_distributor", "gic_redistributor",
            "memory_map", "dram_size", "hardware_profile_sha256", "roundtrip_verified")
    print(json.dumps({k: report.get(k) for k in keep}, indent=2)[:1200])
    (OUT / "adt-run.json").write_text(json.dumps({
        "command": cmd, "seed_sha_source": dtb_sha, "dram_size": hex(DRAM),
        "banks": [[hex(b), hex(s)] for b, s in BANKS],
        "adt": str(adt), "report": report,
    }, indent=2) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
