#!/usr/bin/env python3
"""组本机 umi 的 XNU 引导卷（64 MiB FAT32 ramdisk）。

内容：源码内核 + 本机 ADT + 两个屏读 App，外加菜单配置。
卷写法与上游 scripts/unixnu/payload.py 一致（mformat -C -F、TZ=UTC、EPOCH mtime），
这样固件侧 UmiRamPayloadDxe 的校验口径不用改。
"""
import argparse
import hashlib
import json
import os
import shutil
import struct
import subprocess
import sys
from pathlib import Path

WS = Path("/home/unixnu/code/umi-work-pin")
UEFI = Path("/home/unixnu/code/uefi-umi-b")
BUILD = UEFI / "Build/umiPkg/DEBUG_CLANGPDB/AARCH64"
OUT = WS / "out/umi/xnu"
STAGE = OUT / "stage2"
IMAGE = OUT / "umi-xnu-fat.img"
KERNEL = WS / "out/umi-xnu/umi/kernel/source-kernel.macho"
ADT = OUT / "stage/Payloads/kernel.macho.adt"
EPOCH = 315532800  # 1980-01-01，FAT 最早时间戳，保持卷可复现
SIZE_MIB = 64
SECTORS = SIZE_MIB * 2048
LABEL = "UMIXNU"

MENU = """version = 1

[boot]
timeout = 5
fallback_timeout = 3600
default = "xnu"
rotate = 0
connect_all = true

[ui]
title = "Mi 10 8G - XNU bring-up"

[kits]
autoload = false

[[entry]]
id = "xnu"
title = "Boot source XNU"
type = "xnu"
path = "Payloads/kernel.macho"
args = "-v keepsyms=1 kt_fixed_zones=120"

[[entry]]
id = "boot-log"
title = "Read boot log"
type = "efi"
path = "Payloads/UmiBootLog.efi"

[[entry]]
id = "memory-diag"
title = "Read memory maps"
type = "efi"
path = "Payloads/UmiMemoryDiag.efi"

[[entry]]
id = "reset"
title = "Restart"
type = "action"
action = "reset"
"""

APPS = ("UmiBootLog", "UmiMemoryDiag")
ARGS = "-v keepsyms=1 kt_fixed_zones=120"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(cmd, env=None):
    result = subprocess.run(cmd, capture_output=True, text=True, env=env)
    if result.returncode != 0:
        sys.exit(f"命令失败 rc={result.returncode}: {' '.join(map(str, cmd))}\n{result.stderr[:600]}")
    return result.stdout


def machine(path):
    data = path.read_bytes()
    offset = struct.unpack_from("<I", data, 0x3C)[0]
    return struct.unpack_from("<H", data, offset + 4)[0]


def adt_has_ramdisk(path):
    """loader 只认 /chosen/memory-map 里的 RAMDisk 占位，缺了就没人把 initrd 交进内存。"""
    sys.path.insert(0, str(WS / "devices/umi/scripts"))
    from umi_adt import decode
    return "RAMDisk" in decode(path.read_bytes()).at("/chosen/memory-map").properties


def main():
    ap = argparse.ArgumentParser(description="组本机 umi 的 XNU 引导卷（64 MiB FAT32 ramdisk）")
    ap.add_argument("--mockfs-initrd", type=Path,
                    help="发布成 Payloads/launchd.macho，并用 rd=md0 让内核挂 mockfs RAM 假根")
    cli = ap.parse_args()
    mockfs = cli.mockfs_initrd.resolve() if cli.mockfs_initrd else None
    if mockfs and (not mockfs.is_file() or mockfs.stat().st_size < 4096):
        sys.exit(f"mockfs initrd 要是至少一页的常规文件：{mockfs}")
    menu = MENU
    if mockfs:
        marker = 'path = "Payloads/kernel.macho"\n'
        if menu.count(marker) != 1:
            sys.exit("菜单里没有唯一的 XNU 条目")
        menu = menu.replace(marker, marker + 'initrd = "Payloads/launchd.macho"\n')
        menu = menu.replace(f'args = "{ARGS}"', f'args = "rd=md0 {ARGS}"')

    for path in (KERNEL, ADT):
        if not path.is_file():
            sys.exit(f"缺少输入：{path}")

    efi = {}
    for name in APPS:
        candidate = BUILD / f"umiPkg/Application/{name}/{name}/OUTPUT/{name}.efi"
        if not candidate.is_file():
            sys.exit(f"应用未编出：{candidate}")
        if machine(candidate) != 0xAA64:
            sys.exit(f"{name}.efi 不是 AArch64")
        efi[name] = candidate

    shutil.rmtree(STAGE, ignore_errors=True)
    payloads = STAGE / "EFI/UniXNU/Payloads"
    payloads.mkdir(parents=True)
    (STAGE / "EFI/UniXNU/unixnu.toml").write_text(menu)
    shutil.copyfile(KERNEL, payloads / "kernel.macho")
    shutil.copyfile(ADT, payloads / "kernel.macho.adt")
    if mockfs:
        shutil.copyfile(mockfs, payloads / "launchd.macho")
    for name, path in efi.items():
        shutil.copyfile(path, payloads / f"{name}.efi")
        if sha(payloads / f"{name}.efi") != sha(path):
            sys.exit(f"暂存副本与源不一致：{name}")

    for path in sorted([STAGE, *STAGE.rglob("*")]):
        os.utime(path, (EPOCH, EPOCH))

    IMAGE.unlink(missing_ok=True)
    env = dict(os.environ, MTOOLS_SKIP_CHECK="1", TZ="UTC")
    run(["mformat", "-C", "-F", "-T", str(SECTORS), "-v", LABEL,
         "-N", "53484e47", "-i", str(IMAGE), "::"], env=env)
    for entry in sorted(STAGE.iterdir()):
        run(["mcopy", "-i", str(IMAGE), "-s", "-Q", "-m", str(entry), "::/"], env=env)

    listing = run(["mdir", "-i", str(IMAGE), "-s", "::"], env=env)
    boot = IMAGE.read_bytes()[:512]
    # FAT32 BPB 字段偏移
    bps = struct.unpack_from("<H", boot, 11)[0]
    spc = boot[13]
    rsvd = struct.unpack_from("<H", boot, 14)[0]
    fats = boot[16]
    sectors = struct.unpack_from("<I", boot, 32)[0]
    sectors_per_fat32 = struct.unpack_from("<I", boot, 36)[0]
    ext_flags = struct.unpack_from("<H", boot, 40)[0]
    version = (boot[42], boot[43])
    root_cluster = struct.unpack_from("<I", boot, 44)[0]
    sig = struct.unpack_from("<H", boot, 510)[0]

    report = {
        "image": str(IMAGE),
        "image_bytes": IMAGE.stat().st_size,
        "image_sha256": sha(IMAGE),
        "label": LABEL,
        "fat": {
            "bytes_per_sector": bps, "sectors_per_cluster": spc, "reserved": rsvd,
            "fats": fats, "total_sectors": sectors, "sectors_per_fat": sectors_per_fat32,
            "ext_flags": hex(ext_flags), "version": list(version), "signature": hex(sig),
        },
        "kernel_sha256": sha(KERNEL), "kernel_bytes": KERNEL.stat().st_size,
        "adt_sha256": sha(ADT), "adt_bytes": ADT.stat().st_size,
        "apps": {name: sha(path) for name, path in efi.items()},
        "menu_args": f"rd=md0 {ARGS}" if mockfs else ARGS,
        "mockfs_initrd": None if not mockfs else
            {"path": str(mockfs), "bytes": mockfs.stat().st_size, "sha256": sha(mockfs)},
        "hardware_tested": False,
    }
    (OUT / "payload-report.json").write_text(json.dumps(report, indent=2) + "\n")

    checks = [
        ("卷大小 == 64 MiB", IMAGE.stat().st_size == SECTORS * 512),
        ("bps == 512", bps == 512),
        ("引导扇区签名 0xAA55", sig == 0xAA55),
        ("总扇区 == 131072", sectors == SECTORS),
        ("根簇 == 2", root_cluster == 2),
        ("假根 initrd 与 rd=md0 已入菜单", not mockfs or
         ('initrd = "Payloads/launchd.macho"' in menu and 'args = "rd=md0 ' in menu)),
        ("ADT 里有 RAMDisk 占位（loader 交接位）", not mockfs or adt_has_ramdisk(ADT)),
    ]
    print(f"  附带 保留扇区 {rsvd} / FAT 数 {fats} / 每簇 {spc} 扇区 / "
          f"每 FAT {sectors_per_fat32} 扇区 / 扩展标志 {hex(ext_flags)} / 版本 {version}")
    print(f"镜像 {IMAGE}  {IMAGE.stat().st_size:,} B  sha {report['image_sha256'][:16]}…")
    for label, ok in checks:
        print(f"  {'OK  ' if ok else 'FAIL'}{label}")
    print("  卷内文件：")
    for line in listing.strip().splitlines():
        print("   ", line.strip())
    return 0 if all(ok for _, ok in checks) else 1


if __name__ == "__main__":
    sys.exit(main())
