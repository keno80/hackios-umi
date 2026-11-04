#!/usr/bin/env python3
"""把真 Apple 21H461 的 /sbin/launchd 与 /usr/lib/dyld 装进 mockfs 的 N4KROOT 假根容器。

容器格式与内核闸口径见 bsd/miscfs/mockfs/mockfs_vfsops.c 的 N4KROOT 分支；
名字映射见 mockfs_vnops.c 的 mockfs_lookup：launchd→launch 槽，dyld→test 槽。
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

EXPECTED = {
    "launchd": "8cec9a3c44a443b08e977ccc5d577850316ad428c575dc01f09b018dbd5b6a25",
    "dyld": "f8df3c58fae6e409db740df22c98aa699aee110b73523541a63f1bd5e23cf705",
}
# 上游 fixture 期望的 CDHash 前 20 字节（本树算出来是 sha256，取前缀对）
EXPECTED_CD = {"launchd": "1d52c69747dffc4b1937d241bdbc9cee3b22df18",
               "dyld": "b479f90e05545314cb843410c3d98ef84d926710"}
# 本树 EXTERNAL_HEADERS/mach-o/loader.h:116 —— MH_DYLINKER 是 0x7（不是常见的 6）
MH_EXECUTE, MH_DYLINKER = 0x2, 0x7
LC_LOAD_DYLINKER, LC_ID_DYLINKER = 0x0E, 0x0F
LC_CODE_SIGNATURE = 0x1D
SUPERBLOB, CODE_DIRECTORY_SHA1, CODE_DIRECTORY_SHA256 = 0xFADE0CC0, 0xFADE0B01, 0xFADE0C02
DEFAULT_SRC = Path("/home/unixnu/code/umi-work-pin/out/umi-xnu/apple-el0")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def parse_macho(data: bytes, name: str) -> dict:
    magic, cputype, cpusubtype, filetype, ncmds, _, flags, _ = struct.unpack_from("<8I", data)
    if (magic, cputype, cpusubtype) != (0xFEEDFACF, 0x0100000C, 0):
        raise SystemExit(f"FAIL {name}: 不是普通 ARM64 Mach-O（{magic:#x},{cputype:#x},{cpusubtype:#x}）")
    at, linkers, signature = 32, [], None
    for _ in range(ncmds):
        cmd, length = struct.unpack_from("<II", data, at)
        if cmd in (LC_LOAD_DYLINKER, LC_ID_DYLINKER):
            # lc_str 是相对本条 load command 起点的偏移
            off = struct.unpack_from("<I", data, at + 8)[0]
            end = data.index(b"\0", at + off)
            linkers.append((data[at + off:end]).decode())
        elif cmd == LC_CODE_SIGNATURE:
            signature = struct.unpack_from("<II", data, at + 8)
        at += length
    return dict(name=name, bytes=len(data), filetype=filetype, ncmds=ncmds, flags=flags,
                dylinker=linkers, signature=signature)


def cdhash(data: bytes, info: dict) -> dict:
    """从 LC_CODE_SIGNATURE 反推第一张 CodeDirectory 的 CDHash（Apple 侧展示的就是它的摘要）。"""
    if not info["signature"]:
        return {"cdhash": None, "why": "no LC_CODE_SIGNATURE"}
    off, size = info["signature"]
    # 代码签名结构是网络序（大端），文件里的 dataoff/datasize 才是小端。
    if struct.unpack_from(">I", data, off)[0] != SUPERBLOB:
        return {"cdhash": None, "why": f"signature 不是 superblob（{struct.unpack_from('>I', data, off)[0]:#x}）"}
    first = off + struct.unpack_from(">I", data, off + 16)[0]
    magic, cdlen = struct.unpack_from(">II", data, first)
    digest = hashlib.sha256 if magic == CODE_DIRECTORY_SHA256 else hashlib.sha1
    if magic not in (CODE_DIRECTORY_SHA1, CODE_DIRECTORY_SHA256):
        return {"cdhash": None, "why": f"未知 CD magic {magic:#x}"}
    blob = data[first:first + cdlen]
    return {"cdhash": digest(blob).hexdigest(), "algo": digest().name,
            "upstream_cdhash_match": digest(blob).hexdigest().startswith(EXPECTED_CD[info["name"]])}


def align4096(value: int) -> int:
    return (value + 4095) & ~4095


def kernel_refusals(header, bytes_total):
    """逐条复刻 mockfs_vfsops.c 的 EINVAL 条件，出图前先自己过一遍。"""
    magic, version, count, launch_at, launch_size, test_at, test_size = header
    checks = [
        (magic == b"N4KROOT\0", "magic"),
        (version == 1, "version 必须是 1"),
        (count == 2, "count 必须是 2"),
        (bytes_total <= 32 * 1024 * 1024, "整卷超 32 MiB"),
        (launch_at == 4096, "launch_offset 必须 4096"),
        (launch_size > 0 and test_size > 0, "两段尺寸不能为 0"),
        (not test_at & 4095, "test_offset 未 4K 对齐"),
        (test_at >= 8192, "test_offset < 8192"),
        (test_at <= bytes_total, "test_offset 越过卷尾"),
        (launch_size <= test_at - launch_at, "launch 段伸进 test 槽"),
        (test_size <= bytes_total - test_at, "test 段越过卷尾"),
    ]
    return [why for ok, why in checks if not ok]


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--src", type=Path, default=DEFAULT_SRC, help="apple-el0 取源目录")
    ap.add_argument("--out", type=Path, default=Path("/mnt/e/Code/HackIos/out/fixtures/root-real.macho"))
    ap.add_argument("--allow-hash-drift", action="store_true",
                    help="允许输入哈希与上游 21H461 期望值不一致（默认拒绝， provenance 是这步的全部意义）")
    cli = ap.parse_args()

    report = {}
    blobs = []
    for name in ("launchd", "dyld"):
        path = (cli.src / name).resolve()
        data = path.read_bytes()
        digest = hashlib.sha256(data).hexdigest()
        info = parse_macho(data, name)
        if digest != EXPECTED[name] and not cli.allow_hash_drift:
            raise SystemExit(f"FAIL {name}: sha256 {digest} 与上游 21H461 期望值不一致")
        info.update(sha256=digest, path=str(path), **cdhash(data, info))
        report[name] = info
        blobs.append(data)
    launchd, dyld = blobs
    gates = [
        (report["launchd"]["filetype"] == MH_EXECUTE,
         f"launchd filetype={report['launchd']['filetype']} 不是本树的 MH_EXECUTE(0x2)"),
        (report["dyld"]["filetype"] == MH_DYLINKER,
         f"dyld filetype={report['dyld']['filetype']} 不是本树的 MH_DYLINKER(0x7)，内核 case 会走 default→LOAD_FAILURE"),
        ("/usr/lib/dyld" in report["launchd"]["dylinker"],
         f"launchd 的 LC_LOAD_DYLINKER={report['launchd']['dylinker']}；mockfs 只把 \"dyld\" 这个名字解析到 test 槽"),
        (report["launchd"]["upstream_cdhash_match"] and report["dyld"]["upstream_cdhash_match"],
         "CDHash 前缀与上游 fixture 期望值不符：这已经不是 Apple 原件"),
    ]
    gate_failures = [why for ok, why in gates if not ok]
    if gate_failures and not cli.allow_hash_drift:
        raise SystemExit("FAIL " + "; ".join(gate_failures))

    launch_at = 4096
    test_at = align4096(launch_at + len(launchd))
    total = align4096(test_at + len(dyld))
    image = bytearray(total)
    header = (b"N4KROOT\0", 1, 2, launch_at, len(launchd), test_at, len(dyld))
    struct.pack_into("<8sII4Q", image, 0, *header)
    image[launch_at:launch_at + len(launchd)] = launchd
    image[test_at:test_at + len(dyld)] = dyld

    refused = kernel_refusals(struct.unpack_from("<8sII4Q", bytes(image), 0), total)
    if refused:
        raise SystemExit("FAIL 内核会拒收这个容器：" + "; ".join(refused))

    cli.out.parent.mkdir(parents=True, exist_ok=True)
    cli.out.write_bytes(bytes(image))
    meta = dict(inputs=report, container=dict(bytes=total, launch_offset=launch_at,
                                             launch_size=len(launchd), test_offset=test_at,
                                             test_size=len(dyld), sha256=sha(cli.out)),
                kernel_refusals=refused, macho_gate_failures=gate_failures,
                apple_signed_files_unmodified=True,
                source="IPSW 21H461 OS dmg -> Apple_APFS 分区 -> pyfsapfs read_buffer")
    cli.out.with_suffix(".json").write_text(json.dumps(meta, indent=2) + "\n")
    print(json.dumps(meta, indent=2))


if __name__ == "__main__":
    main()
