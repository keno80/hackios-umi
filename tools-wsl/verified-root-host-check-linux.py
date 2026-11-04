#!/usr/bin/env python3
"""kits/VerifiedRoot/tests/check.py 的 Linux 等价件——断言逐条照搬，只换三处本机假设。

1. host 共享件：上游用 `xcrun clang -dynamiclib`（Mach-O）。本机的 `xcrun clang` 是
   scripts/linux/clang 那层壳，会强制 `-target arm64e-apple-macos26.0`（交叉件），
   而且不认 `-dynamiclib`（实测报 argument unused during compilation）。所以 host 件走系统
   `cc`（真实宿主 x86-64）+ `-shared -fPIC`。
   产物名仍叫 verified-root.dylib——官方 prepare_umi_root_policy.py 按这个固定路径 ctypes.CDLL，
   它只认 ELF；这不是伪装，格式在 checks.json 里单列，见 host_shared_object_format。
2. arm64 交叉段仍用 `xcrun clang -target arm64-apple-ios17.0`（与官方 build_umi_root_bundle.py
   同一把编译器），SDK 由 --ios-sdk / UNIXNU_SDKROOT 指。
3. openssl：上游 --openssl-prefix /opt/homebrew/opt/openssl@3。本机是系统 openssl 3.0.13，
   头在 /usr/include、库在 /usr/lib/x86_64-linux-gnu，所以 --libdir 与 --includedir 分开给。
   这一段只出 verified-root-arm64.o，是「同源 C 件能按目标 ABI 编出来」的证据；拿不到 SDK 就照实记 native_arm64_ios17_cross_compile=False，不吹。

RSA 密钥、签名信封、逐块校验的断言集合与上游一致，一条没删。
"""
import argparse
import ctypes
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import uuid

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("--kit", type=Path, required=True,
                    help="kits/VerifiedRoot 目录")
parser.add_argument("--openssl-prefix", type=Path, default=Path("/usr"))
parser.add_argument("--libdir", type=Path, default=None,
                    help="libcrypto 所在目录，默认 <prefix>/lib/x86_64-linux-gnu 或 <prefix>/lib")
parser.add_argument("--includedir", type=Path, default=None)
parser.add_argument("--cc", default=None,
                    help="host 编译器，默认 cc（系统宿主编译器）；不要用 xcrun clang，那层壳强制 arm64 交叉")
parser.add_argument("--target-cc", default="xcrun clang",
                    help="arm64 交叉段编译器，默认 xcrun clang（与官方 build_umi_root_bundle.py 同把）")
parser.add_argument("--ios-sdk", default=None,
                    help="iPhoneOS SDK 根，默认取 xcrun --show-sdk-path，再退 UNIXNU_SDKROOT")
args = parser.parse_args()

KIT = args.kit.resolve()
out = args.output.resolve()
out.mkdir(parents=True, exist_ok=True)

prefix = args.openssl_prefix
includedir = args.includedir or (prefix / "include")
libdir = args.libdir
if libdir is None:
    for cand in (prefix / "lib" / "x86_64-linux-gnu", prefix / "lib64", prefix / "lib"):
        if (cand / "libcrypto.so").exists() or (cand / "libcrypto.dylib").exists():
            libdir = cand
            break
    else:
        raise SystemExit(f"找不到 libcrypto：{prefix}")

if args.cc:
    cc = args.cc.split()
else:
    # 本机 PATH 首位是 UniXNU 工具链（$TC/CommandLineTools/usr/bin）。实测（u102）：
    #   * 那层 clang 壳强制 -target arm64e-apple-macos26.0，出的是交叉件，宿主件不能用它；
    #   * /usr/bin/gcc 更糟——它 -print-prog-name=ld 得到裸 ld，被 PATH 里的 iOS ld 壳抢走，
    #     报 'clang: error: unknown argument: --64'；
    #   * /usr/bin/clang（Ubuntu clang 18.1.3）在带/不带我们 PATH 两种环境下都出 x86-64 ELF。
    # 所以宿主件默认 /usr/bin/clang。
    cc = None
    for candidate in ("/usr/bin/clang", "/usr/bin/gcc", "/usr/bin/cc"):
        if Path(candidate).exists():
            cc = [candidate]
            break
    if cc is None:
        raise SystemExit("找不到宿主编译器 /usr/bin/clang|gcc|cc")
target_cc = args.target_cc.split()

keys = out / "keys"
keys.mkdir(mode=0o700, exist_ok=True)
os.chmod(keys, 0o700)
for name in ("owner", "other"):
    private, public = keys / (name + ".pem"), keys / (name + "-public.pem")
    if not private.exists():
        fd = os.open(private, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        os.close(fd)
        subprocess.run(["openssl", "genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:3072",
                        "-out", private], check=True, capture_output=True)
    os.chmod(private, 0o600)
    subprocess.run(["openssl", "pkey", "-in", private, "-pubout", "-out", public], check=True, capture_output=True)

spec = importlib.util.spec_from_file_location("manifest", KIT / "tools/manifest.py")
manifest = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manifest)
data = bytes((i * 23 + i // 4096) & 255 for i in range(4096 * 3 + 512))
record = manifest.make(io.BytesIO(data), len(data), keys / "owner.pem", keys / "owner-public.pem",
                       uuid.UUID("01e286f1-f4dd-4b2f-99d9-4973337fc788"), 7, out / "signed")

library = out / "verified-root.dylib"
host_flags = ["-std=c11", "-Wall", "-Wextra", "-Werror", "-shared", "-fPIC",
              "-I", KIT / "include", "-I", includedir]
# CCC_OVERRIDE_OPTIONS 里那串 -Wno-* 只有我们的定制 clang 认（u104 实测：Ubuntu clang 18
# 收到 -Wno-missing-designated-field-initializers 直接 -Werror,-Wunknown-warning-option 死）。
# 宿主件走系统 clang，必须把这条环境清掉；arm64 交叉段仍保留（那边是定制 clang）。
host_env = {k: v for k, v in os.environ.items() if k != "CCC_OVERRIDE_OPTIONS"}
multiarch = subprocess.run([*cc, "-print-multiarch"], capture_output=True,
                           text=True, env=host_env).stdout.strip()
if multiarch and (Path("/usr/include") / multiarch).is_dir():
    # clang 系的宿主编译器不会自己带 Debian 多架构头目录，gcc 会；补上两类都走得通。
    host_flags += ["-isystem", str(Path("/usr/include") / multiarch)]
host_flags += [KIT / "src/verified_root.c", KIT / "tests/openssl_provider.c",
               "-L", libdir, "-lcrypto", "-o", library]
subprocess.run([*cc, *host_flags], check=True, env=host_env)
print(f"host 共享件：{library} <- {' '.join(cc)} -shared（Linux ELF，非 Mach-O；已清 CCC_OVERRIDE_OPTIONS）")

arm64_object = None
arm64_error = "没有可用的 iPhoneOS SDK"
sdks = []
if args.ios_sdk:
    sdks.append(args.ios_sdk)
try:
    reported = subprocess.check_output([*target_cc[:1], "--sdk", "iphoneos", "--show-sdk-path"],
                                       text=True).strip() if shutil.which(target_cc[0]) else ""
    if reported and reported not in sdks:
        sdks.append(reported)
except Exception as error:
    arm64_error = f"{target_cc[0]} --show-sdk-path 失败：{error}"
env_sdk = os.environ.get("UNIXNU_SDKROOT")
if env_sdk and env_sdk not in sdks:
    sdks.append(env_sdk)
for resolved in sdks:
    cmd = [*target_cc, "-isysroot", resolved, "-target", "arm64-apple-ios17.0", "-std=c11", "-ffreestanding",
           "-Wall", "-Wextra", "-Werror", "-I", KIT / "include",
           "-c", KIT / "src/verified_root.c", "-o", out / "verified-root-arm64.o"]
    try:
        subprocess.run(cmd, check=True)
        arm64_object = out / "verified-root-arm64.o"
        arm64_error = None
        break
    except subprocess.CalledProcessError as error:
        arm64_error = f"arm64 交叉编译失败（SDK={resolved}）：rc={error.returncode}"
    except FileNotFoundError:
        arm64_error = f"找不到交叉编译器 {target_cc[0]}"
        break

class View(ctypes.Structure):
    _fields_ = [("hashes", ctypes.c_void_p), ("image_bytes", ctypes.c_uint64), ("block_count", ctypes.c_uint64),
                ("generation", ctypes.c_uint64), ("volume_uuid", ctypes.c_uint8 * 16), ("image_sha256", ctypes.c_uint8 * 32)]


native = ctypes.CDLL(str(library))
native.vr_host_open.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_uint64, ctypes.POINTER(View)]
native.vr_host_open.restype = ctypes.c_int
native.vr_host_block.argtypes = [ctypes.POINTER(View), ctypes.c_uint64, ctypes.c_void_p, ctypes.c_size_t]
native.vr_host_block.restype = ctypes.c_int
envelope = (out / "signed/manifest.bin").read_bytes()
key = (out / "signed/trusted-key.bin").read_bytes()
other_key = manifest.public_anchor(keys / "other-public.pem")
assert len(key) == 395
buffers = []
checks = []


def opened(blob, anchor=key, generation=7, expected=0):
    encoded, trusted, view = ctypes.create_string_buffer(blob), ctypes.create_string_buffer(anchor), View()
    result = native.vr_host_open(encoded, len(blob), trusted, generation, ctypes.byref(view))
    assert result == expected, (result, expected)
    if result:
        assert not view.hashes and view.image_bytes == 0
    buffers.extend((encoded, trusted))
    return view


view = opened(envelope)
assert view.image_bytes == len(data) and view.block_count == 4 and view.generation == 7
assert bytes(view.volume_uuid) == uuid.UUID(record["volume_uuid"]).bytes
checks.append("real RSA3072-SHA256 verification and signed metadata")
for index in range(4):
    block = data[index * 4096:(index + 1) * 4096]
    assert native.vr_host_block(ctypes.byref(view), index, block, len(block)) == 0
checks.append("all original blocks including the exact final 512-byte tail")
for index in range(4):
    block = bytearray(data[index * 4096:(index + 1) * 4096])
    block[0] ^= 1
    assert native.vr_host_block(ctypes.byref(view), index, bytes(block), len(block)) == 5
checks.append("one-byte mutation refused in every actual block")
assert native.vr_host_block(ctypes.byref(view), 1, data[:4096], 4096) == 5
assert native.vr_host_block(ctypes.byref(view), 4, data[:4096], 4096) == 5
assert native.vr_host_block(ctypes.byref(view), 0, data[:512], 512) == 5
checks.append("block substitution, outside index and partial-block reads refused")
for offset, expected in ((40, 3), (160, 3), (544, 4)):
    changed = bytearray(envelope)
    changed[offset] ^= 1
    opened(bytes(changed), expected=expected)
checks.append("signed UUID/header, RSA signature and hash-table mutation refused")
opened(envelope, anchor=other_key, expected=2)
opened(envelope, generation=8, expected=1)
opened(envelope, generation=0, expected=1)
opened(envelope[:-1], expected=1)
opened(envelope + b"\0", expected=1)
checks.append("wrong trusted anchor, rollback generation, truncation and trailing bytes refused")
changed = bytearray(envelope)
changed[120:152] = __import__("hashlib").sha256(other_key).digest()
opened(bytes(changed), anchor=other_key, expected=3)
checks.append("matching attacker-selected key identifier cannot replace the actual RSA signature")
report = dict(real_c_parser=True, real_openssl_signature_verification=True,
              native_arm64_ios17_cross_compile=bool(arm64_object),
              arm64_object=str(arm64_object) if arm64_object else None,
              arm64_error=arm64_error,
              host_compiler=cc, host_shared_object_flags=["-shared", "-fPIC"],
              host_shared_object_format="ELF (Linux); 文件名沿用官方 verified-root.dylib",
              host_env_cleared=["CCC_OVERRIDE_OPTIONS (只有定制 clang 认那串 -Wno-*，见 u104)"],
              openssl_prefix=str(prefix), openssl_libdir=str(libdir), openssl_includedir=str(includedir),
              checks=checks, upstream_reference="kits/VerifiedRoot/tests/check.py",
              qemu_tested=False, boot_root_authenticated=False, hardware_tested=False)
(out / "checks.json").write_text(json.dumps(report, indent=2) + "\n")
print("PASS:", len(checks), "groups using real RSA signatures and actual C block verification; host only")
print("arm64 交叉段:", "过了" if arm64_object else f"没过（{arm64_error}）")
