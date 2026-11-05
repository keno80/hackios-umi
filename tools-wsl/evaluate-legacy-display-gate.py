#!/usr/bin/env python3
"""U 步之九：显示闸在 gate 停点（_native_legacy_display_checkpoint）的本地判读件。

为什么需要它，而不是直接吃官方 analyze_umi_data_display_qemu.py：
  官方件第 48 行无条件断言 Data 身份三合一
  （`native_owner_data_seed_sha256 == native_ram_block_seed_sha256 == seed["sha256"]`），
  而显示生命周期的终结点（LegacyDisplayProbe.cpp:272-383 的 checkpoint）**早于**
  Data RAM 块的种子化——57 档实测 `native_owner_data_status=0xFFFFFFFF`、
  `native_ram_block_writes=0`，那条 assert 必炸（exit=1），跟显示这一格好不好无关。
  所以：官方件仍是 runtime 长窗口档的权威判读；本件只做同一套显示五条公式，
  在到齐那一刻就能出结论——判据一字未增删（analyze_umi_data_display_qemu.py:53-56）。

停点必须是 checkpoint 本体：pc 等于 `_native_legacy_display_checkpoint` 的地址，
且 `bounded_timeout_interrupted=False`（真停，不是超时停）。

用法：evaluate-legacy-display-gate.py RUN_DIR [--kernel MACHO] [--nm NM]
"""
import argparse
import json
import subprocess
import sys
from pathlib import Path

CRITERIA = [
    ("native_legacy_stage", 10, "== 10（late probe 走完 phase==4 成功路）"),
    ("native_legacy_start_result", 1, "== 1（display->start(nub) 真返回成功）"),
    ("native_legacy_registration_calls", None, "> 0（显示件把自己注册上了）"),
    ("native_legacy_gop_virtual", None, "!= 0（GOP 帧缓冲映射出虚拟址）"),
    ("native_legacy_guard_slot", 0, "== 0（原版厂商叶子从没被调到）"),
]
CONTEXT = ["native_legacy_meta_status", "native_legacy_object_size", "native_legacy_parent_match",
           "native_legacy_init_result", "native_legacy_dt_attached", "native_legacy_surface_status",
           "native_legacy_surface_found", "native_legacy_gop_physical", "native_legacy_gop_bytes",
           "native_legacy_gop_width", "native_legacy_gop_height", "native_legacy_client_calls",
           "native_legacy_client_pid", "native_legacy_client_status", "native_legacy_retirement_calls",
           "native_legacy_transfer_calls", "native_legacy_prepare_calls", "native_legacy_copy_n",
           "boot_progress_display_owned", "native_owner_data_status", "native_ram_block_writes",
           "initproc_spawned"]

# 帧提交面的尺寸唯一出处 = LegacyDisplayProbe.cpp 的 volatile 声明（u510 原文）；
# elem 是元素字节数（数组解成分量用）。符号间距实测也对得上（frame_kind 128、frame_stats 1280）。
SIZES = {
    "native_legacy_frame_count": (4, 4), "native_legacy_frame_kind": (128, 4),
    "native_legacy_frame_time": (128, 4), "native_legacy_frame_stats": (1280, 8),
    "native_legacy_frame_colors": (128, 4), "native_legacy_frame_color_counts": (256, 8),
    "native_legacy_frame_color_other": (64, 8),
    "native_legacy_copy_n": (8, 8), "native_legacy_copy_last": (8, 8), "native_legacy_copy_max": (8, 8),
    "native_legacy_copy_sum": (8, 8), "native_legacy_copy_bytes_last": (8, 8),
    "native_legacy_copy_bytes_sum": (8, 8),
    "native_legacy_retired_generation": (4, 4), "native_legacy_presented_generation": (4, 4),
    "native_legacy_retired_frames": (4, 4), "native_legacy_retired_current": (8, 8),
    "native_legacy_retired_pending": (8, 8),
    "native_legacy_swap_validation_calls": (4, 4), "native_legacy_swap_validation_result": (4, 4),
    "native_legacy_swap_validation_reason": (4, 4), "native_legacy_swap_request": (8, 8),
    "native_legacy_swap_surface": (8, 8), "native_legacy_swap_accepted_count": (4, 4),
    "native_legacy_swap_rejected_count": (4, 4), "native_legacy_rej_reason": (4, 4),
    "native_legacy_rej_surfaces": (32, 8), "native_legacy_transfer_bytes": (8, 8),
    "native_legacy_transfer_request": (8, 8), "native_legacy_client_type": (4, 4),
    "native_legacy_client_task": (8, 8), "native_legacy_client_object": (8, 8),
    "native_legacy_client_class": (64, 1), "native_legacy_pm_stage": (4, 4),
    "native_legacy_pm_calls": (4, 4), "native_legacy_pm_callbacks": (4, 4),
    "native_legacy_pm_ordinal": (4, 4), "native_legacy_pm_status": (4, 4),
    "native_legacy_unit_scale_calls": (4, 4), "native_legacy_unit_scale_status": (4, 4),
    "native_legacy_chosen_scale": (4, 4), "native_legacy_chosen_rotation": (4, 4),
    "native_legacy_object": (8, 8), "native_legacy_nub": (8, 8), "native_legacy_workloop": (8, 8),
    "native_legacy_video_base": (8, 8), "native_legacy_video_bytes": (8, 8),
    "native_legacy_gop_map": (8, 8), "native_legacy_properties_length": (4, 4),
    "native_legacy_released": (4, 4), "native_legacy_probe_match": (4, 4),
}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("run", type=Path)
    ap.add_argument("--kernel", type=Path, default=None,
                    help="prelink 件；默认从 run 的 provenance.source_kernel 取")
    ap.add_argument("--nm", default="nm")
    ap.add_argument("--check-keys", action="store_true",
                    help="只核对读址键与声明尺寸（跑完档先跑这个；"
                         "本树 QEMU 短读只验「非 E22」，回包 16 字符冒充 80 字节它不说话）")
    args = ap.parse_args()
    run = args.run.resolve()
    stop = json.loads((run / "gdb-stop.json").read_text())
    prov = json.loads((run / "provenance.json").read_text())
    kernel = args.kernel or Path(prov["source_kernel"])
    mem = stop.get("memory", {})

    sym = {}
    out = subprocess.run([args.nm, "-n", str(kernel)], capture_output=True, text=True).stdout
    if not out.strip():
        raise SystemExit(f"nm 空 dump：{args.nm} 不是 cctools 那份，或读不到 {kernel}")
    for line in out.splitlines():
        p = line.split()
        if len(p) == 3:
            sym.setdefault(p[2], int(p[0], 16))

    def key(name, size):
        return f"{sym['_' + name]:#x}:{size:x}" if "_" + name in sym else None

    def raw(name, size):
        k = key(name, size)
        return bytes.fromhex(mem[k]) if k in mem else None

    def want_size(name):
        return SIZES.get(name, (None, None))[0]

    def have(name):
        """符号在位且这档真挂了**声明尺寸**的读址——区分「没读到」与「压根没读」。"""
        if "_" + name not in sym:
            return False
        declared = want_size(name)
        sizes = (declared,) if declared else (4, 8)
        return any(key(name, s) in mem for s in sizes)

    def val(name):
        declared = want_size(name)
        for size in ((declared,) if declared else (4, 8)):
            if "_" + name in sym:
                b = raw(name, size)
                if b is not None:
                    return int.from_bytes(b, "little")
        return None

    if args.check_keys:
        miss = []
        for name, (size, _elem) in sorted(SIZES.items()):
            if "_" + name not in sym:
                print(f"  无符号 {name}")
                continue
            k = key(name, size)
            v = mem.get(k)
            if v is None:
                miss.append(f"{name}:{size}")
                print(f"  没挂读址  {name}:{size}")
            elif len(v) != size * 2:
                print(f"  ⚠ 短读  {name}:{size} 键在、回包 {len(v) // 2} B（要 {size} B）")
            else:
                print(f"  ok      {name}:{size}")
        print(f"\n  缺 {len(miss)} 枚 → ARGS+=(--read-symbol _{m}) 逐条补" if miss else "\n  读址集齐")
        return 1 if miss else 0

    print(f"run = {run.name}   kernel = {kernel.name}")
    print(f"  stop_pc = {stop.get('pc')}   checkpoint 址 = "
          f"{hex(sym.get('_native_legacy_display_checkpoint', 0))}")
    print(f"  停点即 checkpoint = {stop.get('pc') == hex(sym.get('_native_legacy_display_checkpoint'))}")
    print(f"  bounded_timeout_interrupted = {stop.get('bounded_timeout_interrupted')}"
          f"   （gate 档要 False：到齐自己停的，不是熬到超时）")
    print(f"  owned_memory_bytes = {prov.get('owned_memory_bytes')}")

    print("\n== 官方显示五条（analyze_umi_data_display_qemu.py:53-56，判据未增减）==")
    ok = True
    for name, want, why in CRITERIA:
        v = val(name)
        if want is not None:
            hit = v == want
        else:
            hit = bool(v) and (v > 0 if name.endswith("registration_calls") else v != 0)
        ok = ok and hit
        note = "" if have(name) else "   ⚠ 符号在位但这档没挂读址，值不可判"
        print(f"  {'PASS' if hit else 'FAIL'}  {name} = {v}   判据 {why}{note}")
    print(f"  >>> legacy_service_started_and_framebuffer_mapped = {ok}")

    print("\n== 上下文面（不参与判定，用来归因第一条失败的成因）==")
    for name in CONTEXT:
        if "_" + name not in sym:
            print(f"  {name} = 无符号（这档没编进去）")
        elif not have(name):
            print(f"  {name} = 符号在位但未挂读址（要它补 --read-symbol {name}）")
        else:
            print(f"  {name} = {val(name)}")

    print("\n== 帧提交面（官方 analyze 到不了这里：它只 assert retirement_calls）==")
    fc = val("native_legacy_frame_count")
    cn = val("native_legacy_copy_n")
    sw = val("native_legacy_swap_validation_calls")
    print(f"  frame_count(提交帧数) = {fc}   copy_n(拷贝计量) = {cn}   "
          f"swap_validation_calls = {sw}")

    def arr(name):
        """数组类仪表按声明尺寸整块读（读址键是 :80/:100 这种），解成分量；读不到返回 None。"""
        size, elem = SIZES.get(name, (None, None))
        if size is None or "_" + name not in sym:
            return None
        b = raw(name, size)
        if b is None:
            return None
        return [int.from_bytes(b[i:i + elem], "little") for i in range(0, len(b) - elem + 1, elem)]

    if fc and fc > 0:
        kinds = arr("native_legacy_frame_kind") or []
        times = arr("native_legacy_frame_time") or []
        colors = arr("native_legacy_frame_colors") or []
        print(f"  frame_count={fc}  frame_kind 非零槽 = "
              f"{[k for k in kinds if k][:16]}   frame_time 非零槽 = {[t for t in times if t][:8]}")
        print(f"  frame_colors(采样像素) 前 8 = {[hex(c) for c in colors[:8]]}")
        print(f"  copy_last={val('native_legacy_copy_last')} copy_max={val('native_legacy_copy_max')} "
              f"copy_bytes_last={val('native_legacy_copy_bytes_last')} "
              f"copy_bytes_sum={val('native_legacy_copy_bytes_sum')}")
        print(f"  retired_generation={val('native_legacy_retired_generation')} "
              f"presented_generation={val('native_legacy_presented_generation')} "
              f"retired_frames={val('native_legacy_retired_frames')} "
              f"retirement_calls={val('native_legacy_retirement_calls')}")
        print(f"  swap_accepted={val('native_legacy_swap_accepted_count')} "
              f"swap_rejected={val('native_legacy_swap_rejected_count')} "
              f"swap_validation_reason={val('native_legacy_swap_validation_reason')} "
              f"swap_validation_result={val('native_legacy_swap_validation_result')}")
        print("   判读：swap_rejected>0 → 帧被拒，看 swap_validation_reason（1=interrupt context、"
              "2=中断关、3=扫描线预算耗尽，LegacyDisplayProbe.cpp:86-95）；"
              "retired_frames>0 = 帧真退休，与官方 retirement_calls 同证")
    else:
        print("   判读：还没件提交帧。gate 停点在 checkpoint（显示服务刚起），本就该是 0；"
              "要拿这面得用 runtime 长窗口档。")

    print("\n== 分诊表（LegacyDisplayProbe.cpp 实读）==")
    stage = val("native_legacy_stage")
    print(f"  本档 stage = {stage}")
    print("   1 preModLoad / 2 GOP console 校验 / 3 display->init()"
          " / 4 IOSurface 到位并建 nub / 5 start(nub) / 6 失败收尾 / 7-8 release / 10 成功")
    if stage == 10:
        print("   显示生命周期已走完成功路；retirement/copy/client 为 0 是「还没件提交帧」，不是失败")
    elif stage in (1, 2, 3):
        print("   停在早期趟：看 native_legacy_meta_status / PE_current_console 那串校验 / init_result")
    elif stage == 6:
        print("   走到收尾又没到 10：看 surface_status（OSKextLoadKextWithIdentifier(IOSurface)）、"
              "surface_found（IOCoreSurfaceRoot 5 秒等待）、dt_attached（/arm-io 在 gIODTPlane）、"
              "start_result、guard_slot")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
