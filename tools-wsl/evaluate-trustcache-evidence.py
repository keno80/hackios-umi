#!/usr/bin/env python3
"""U 步之四之二判读件：把官方 check_umi_trustcache_qemu.py 的 13 条断言逐条搬到本地实跑结果上。

断言集合与上游一致，不增减；拆开是为了第一次没过时能直接看出是哪一道闸。
额外附一段 lr 归属诊断：trace 每次命中的调用方是否落在 AMFI 的 __TEXT_EXEC 段内，
用来定「launchd 的 AMFI 查询」到底停在哪一发。
用法：evaluate-trustcache-evidence.py <run 名>
"""
import hashlib
import json
import struct
import subprocess
import sys
from pathlib import Path

WS = Path("/home/unixnu/code/umi-work-pin")
KERNEL = WS / "out/umi-xnu/umi/kernel/qemu-trustcache-runtime.macho"
AMFI = "com.apple.driver.AppleMobileFileIntegrity"
TRUSTCACHE_SHA = "7416ca4f8377146626bb284e2133c76bee6cb4e3ee0af5d648b186235a7323a7"

results = []


def check(name, ok, detail=""):
    results.append((name, bool(ok), detail))
    return bool(ok)


def report(failed_hint=""):
    print("== 38-trustcache-query 逐条判读 ==")
    failed = 0
    for name, ok, detail in results:
        print(f"  [{'PASS' if ok else 'FAIL'}] {name}" + (f"   -> {detail}" if detail != "" else ""))
        failed += 0 if ok else 1
    print(f"-- 结论：{len(results) - failed}/{len(results)} 条过，{failed} 条未过")
    if failed_hint:
        print("-- 提示：" + failed_hint)
    return failed


def main():
    run_name = sys.argv[1] if len(sys.argv) > 1 else "38-trustcache-query"
    run = WS / "out/umi-qemu" / run_name
    try:
        data = json.loads((run / "gdb-stop.json").read_text())
    except OSError as error:
        print(f"!! 没有可用快照：{error}")
        return 1
    prov = json.loads((run / "provenance.json").read_text())
    build = json.loads(KERNEL.with_suffix(".source-build.json").read_text())
    plan = json.loads(KERNEL.with_suffix(".json").read_text())
    sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()  # noqa: E731

    digest = sha(KERNEL)
    check("内核 sha 三处一致", digest == data["kernel_sha256"] == prov["kernel_sha256"], digest[:16])
    check("构建档 trust_cache_runtime 且 owner_root=trust",
          build.get("trust_cache_runtime") and build.get("owner_root") == "trust",
          f"trust_cache_runtime={build.get('trust_cache_runtime')} owner_root={build.get('owner_root')}")
    check("非超时中断且真实函数返回栈匹配",
          not data.get("bounded_timeout_interrupted") and data.get("function_return_stack_matched"),
          f"interrupted={data.get('bounded_timeout_interrupted')} "
          f"return_stack_matched={data.get('function_return_stack_matched')}")
    check("x0==0 且 accel==tcg", data.get("x0") == "0x0" and data.get("qemu_accelerator") == "tcg",
          f"x0={data.get('x0')} accel={data.get('qemu_accelerator')}")
    check("未改客户内存且未声明 VMM 属性",
          not prov.get("guest_memory_patched") and not prov.get("vmm_property_declared"),
          f"patched={prov.get('guest_memory_patched')} vmm={prov.get('vmm_property_declared')}")
    check("provenance 里 trustcache sha==原件",
          prov.get("trustcache_sha256") == TRUSTCACHE_SHA, str(prov.get("trustcache_sha256"))[:16])

    symbols = {}
    for line in subprocess.check_output(["xcrun", "nm", "-n", str(KERNEL)], text=True).splitlines():
        f = line.split()
        if len(f) == 3:
            symbols[f[2]] = int(f[0], 16)
    memory = data.get("memory") or {}

    def read(name, n):
        key = f"{symbols[name]:#x}:{n:x}"
        if key not in memory:
            raise KeyError(f"缺观测键 {key}（已有 {sorted(memory)[:4]}…）")
        return bytes.fromhex(memory[key])

    try:
        static_init = read("_trust_cache_static_init", 1)
        static_loaded = read("_trust_cache_static_loaded", 1)
        check("静态信任缓存已初始化且已加载",
              static_init == static_loaded == b"\1", f"init={static_init.hex()} loaded={static_loaded.hex()}")
        lock = read("_trust_cache_rt_lock", 16)
        check("运行时锁首 4 字节非 0（锁组真建起来了）",
              struct.unpack_from("<I", lock)[0] != 0, f"rt_lock={lock.hex()}")
        failures = read("_umi_lock_failure_observation", 512)
        check("锁失败观测面全 0", failures == bytes(512), failures[:8].hex())
        root = struct.unpack("<18Q", read("_umi_owner_root_observation", 144))
        check("owner-root 前六字段==(2,1,80,1,1,1)", root[:6] == (2, 1, 80, 1, 1, 1), str(root[:6]))
        check("挂载/选择/验证设备三者相同且非 0",
              root[6] == root[7] == root[8] != 0, f"{[hex(v) for v in root[6:9]]}")
    except KeyError as error:
        check("观测块齐全", False, str(error))

    traced = {int(e["pc"], 16) for e in data.get("trace_events") or []}
    check("trace 覆盖 _trust_cache_runtime_init 与 _load_init_program",
          symbols.get("_trust_cache_runtime_init") in traced and symbols.get("_load_init_program") in traced,
          f"命中 {len(traced)} 个址")
    pc = int(data["pc"], 16)
    extent = next((e for e in plan["extents"] if e["module"] == AMFI and e["segment"] == "__TEXT_EXEC"), None)
    check("最终 pc 落在 AMFI __TEXT_EXEC 内（= 返回给原版 AMFI）",
          extent is not None and extent["va"] <= pc < extent["va"] + extent["size"],
          f"pc={hex(pc)} 段={hex(extent['va'])}..{hex(extent['va'] + extent['size'])}" if extent else "无 AMFI 段")
    inputs = json.loads((WS / "out/umi/trustcache/inputs.json").read_text())
    check("inputs.json 指向的 bundle sha 一致",
          sha(Path(inputs["bundle"])) == prov.get("trustcache_sha256"), inputs["bundle"])

    failed = report("停点由 --stop/--finish 决定；看下面 lr 归属挑被 AMFI 调用的那一发。")
    print("-- 停点信息 --")
    for key in ("stop_symbol", "pc", "x0", "finished_function_entry", "function_return_target",
                "function_return_stack_matched", "function_entry_arguments"):
        if key in data:
            print(f"  {key} = {data[key]}")
    print("  provenance stop_symbol=%s stop_address=%s component_stop_address=%s" % (
        prov.get("stop_symbol"), prov.get("stop_address"), prov.get("component_stop_address")))
    if extent:
        lo, hi = extent["va"], extent["va"] + extent["size"]
        print("-- trace 命中按调用方归属（lr 在 AMFI 段内 = 可当停点候选）--")
        by_target = {}
        for e in data.get("trace_events") or []:
            by_target.setdefault(int(e["pc"], 16), []).append(int(e["lr"], 16))
        names = {v: k for k, v in symbols.items()}
        for address, lrs in sorted(by_target.items(), key=lambda kv: -len(kv[1]))[:25]:
            inside = sum(1 for lr in lrs if lo <= lr < hi)
            print(f"  {hex(address)} {names.get(address, '?'):44s} 命中{len(lrs):5d} lr在AMFI段内={inside:5d}")
    return failed


if __name__ == "__main__":
    sys.exit(1 if main() else 0)
