# AGENTS.md — 在小米 10 上跑原生 iPadOS（UniXNU / umi）

这份文件是入口地图。会话开始时先读它，别去 `tools-wsl/` 里翻序号脚本——大部分是历史一次性探针。

## 项目是什么

在自己的小米 10（umi / SM8250，8GB+256GB，BL 已解锁，手上没有实体 Mac）上，用
[UniXNU](https://unixnu.com) 把 XNU 内核跑到用户态，最终引导 iPadOS 用户件。
构建主机是 Windows + WSL2 Ubuntu-24.04；真机侧只做零写入的 `fastboot boot`。

推进方式是一条「归因链」：每过一次闸就留一个屏上/日志上的硬证据，再打下一档。
阶段用字母记（A…T 步），每步的取证落在 `out/probes/`，屏幕证据落在 `out/screens/`。

## 环境：两套树，只有一套算数

| 东西 | 路径 | 说明 |
|---|---|---|
| 本仓（Windows） | `E:\Code\HackIos` | WSL 里是 `/mnt/e/Code/HackIos` |
| **构建真正吃的设备树** | `/home/unixnu/code/UniXNU-umi` | **ext4 那份**。Windows 侧同名克隆对构建不可见，改错地方白跑几十分钟 |
| 工作区 | `/home/unixnu/code/umi-work-pin` | `devices/umi` 是 bind mount，指向上面那份（`ensure-dev-bind` 负责） |
| XNU 重放工作树 | `/home/unixnu/code/UniXNU-main/out/umi/tree/.cache/xnu-work` | 补丁按 z 前缀排序重放到这里；直接改这里的文件会被构建还原抹掉 |
| 内核产物 | `/home/unixnu/code/umi-work-pin/out/umi-xnu/umi/kernel/source-kernel.macho` | 判新鲜度看它的 sha256 |
| 构建日志 | `/home/unixnu/code/UniXNU-main/out/unixnu-logs/kernel-walk-*.log` | pid 在同目录 `kernel-walk.pid` |
| 监控面板 | `http://127.0.0.1:8765/` | 从 `/proc` 自动接管在跑的任务，不需要手写状态文件 |

## 重启后：一条命令

宿主机重启会丢三样东西：WSL 本身、`devices/umi` 的 bind mount、`/usr/local/bin` 里的命令快照。

```powershell
wsl.exe -d Ubuntu-24.04 bash -lc "tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/reboot-restore.sh > /tmp/rr.sh; bash /tmp/rr.sh"
```

它做四件事：按白名单重装命令 → 重建 bind → 起 8765 面板 → 打印内核 sha 与在跑的任务。
白名单在 `tools-wsl/sync-helpers.sh` 里，是唯一出处：`unixnu-env` `ensure-dev-bind` `progress`
`dashboard` `rawlog` `run-umi-qemu` `ab-status`（对照实测引用表 `out/probes/entry-pathcmds.txt`）。
`/usr/local/bin/ensure-dev-bind` 如果是旧版会漏「非空目录」判定，把重启留下的空目录误判成需要停手，
构建 kick 会静默失败——所以白名单里那两个命令必须每次用仓库版覆盖。
加 `--prune` 才会清掉 `/usr/local/bin` 里顶层已无同名脚本的陈旧快照（现有 60+ 项历史残留）。

## 调用 WSL 的规矩

一律落脚本文件，别把 WSL 逻辑内联进 `wsl.exe bash -lc "..."`：引号会被吞，实测踩过。

```bash
MSYS2_ARG_CONV_EXCL='*' MSYS_NO_PATHCONV=1 wsl.exe -d Ubuntu-24.04 bash -lc \
  "tr -d '\r' < /mnt/e/Code/HackIos/tools-wsl/<脚本> > /tmp/<脚本>; bash /tmp/<脚本>"
```

脚本自己 `exec > /mnt/e/Code/HackIos/out/probes/<名字>.txt 2>&1`，然后用 Read 读结果。
等后台进程结束，用「证据文件出现/文件里有结束标记」判，别用 `pgrep`。
wsl.exe 直接回显是 UTF-16，看着像二进制，需要 `tr -d '\000'`。

## 入口清单

### 现场与恢复
- `tools-wsl/reboot-restore.sh` — 重启后第一条（见上）
- `tools-wsl/sync-helpers.sh` — 白名单命令安装（唯一出处，`--prune` 清陈旧）
- `tools-wsl/check-env.sh` — 工具链基础包是否落地 + 出网自检
- `tools-wsl/unixnu-env.sh` — 统一代理设置（NAT 网关即宿主，子网会变，动态解析）
- `tools-wsl/ensure-dev-bind.sh` — `devices/umi` bind mount，构建前置

### 内核构建
- `tools-wsl/run-kernel-walk.sh` — **主构建入口**：`build_umi_xnu.py --stage kernel --profile phone --mockfs-root -j 5`
- `tools-wsl/h-wait-kernel.sh` — 等构建结束并取日志尾
- `tools-wsl/preflight-kernel.sh` / `run-kernel-cold|mockfs|screen|trace|pin|main.sh` — 各档位的历史入口，新档从 `run-kernel-walk.sh` 改参数

### 补丁（改 XNU 的唯一通路）
1. 写/改 `tools-wsl/make-*-patch.sh` 或 `tools-wsl/make-*.py`，从 `.cache/xnu-work` 读原文、
   断言锚点命中、`diff -u` 产补丁，直接落 `patches/umi-xnu/zzzz…-umi-<语义>.patch`
2. `tools-wsl/h-install-band.sh` — 把仓库 `patches/` 覆盖安装到 ext4 那份 `UniXNU-umi/patches/umi-xnu/`
3. `tools-wsl/run-kernel-walk.sh` 重编，`tools-wsl/audit-umi-patches.sh` / `sync-umi-patches.sh` 核对重放
4. 二进制层取证：`llvm-nm` + `llvm-objdump` 反汇编看守卫是否真落地（参照 `make-amfi-guard-patch.py` 那一档）

z 前缀长度决定重放顺序，新补丁接在最长串后面。

### 用户态件与容器
- `tools-wsl/build-n4kroot-real.py` — 把真 Apple 的 `/sbin/launchd` + `/usr/lib/dyld` 装进 mockfs 的 `N4KROOT` 假根容器，产 `out/fixtures/root-real.macho`
- `tools-wsl/build-n4k-fixture.sh` / `build-mockfs-fixture.sh` / `repack-mockfs.sh` — 假件容器与历史归档
- 容器只有两槽（launch / test），名字映射见 `mockfs_vnops.c` 的 `mockfs_lookup`

### QEMU 自测
- `tools-wsl/run-umi-qemu.sh NAME --mockfs-initrd <IMG> --args "-v keepsyms=1 kt_fixed_zones=120" --capture-screen --timeout 240`
- 产物：`out/umi-qemu/NAME/screen.png` + `gdb-stop.json`；launch 日志出现 `run_umi_qemu exit=` 即结束
- 停 `_bsd_init` 的资格化快照一律走 `--timeout 600`：300 秒经常撞超时，超时会停在 IOKit 之前的任意点，元类读出来全 0（不是内核问题）
- `tools-wsl/launch-qemu-screen.sh` / `run-qemu-zones.sh` — 历史档位

### U 步：存储资格化（prelink → ABI 活体审计 → 块件/提供者）
- `tools-wsl/run-umi-prelink.sh NAME` — `build_umi_prelink.py --profile qemu --storage`，产 `kernel/NAME.macho` + 同名 `.json`/`.provenance.json`
- `tools-wsl/run-storage-abi-snapshot.sh [基名] [可复用 ESP 档]` — 停 `_bsd_init` 读两个元类 + 带 `SCTLR_EL1` 的系统寄存器，喂 `audit_umi_storage.py` 出 `out/umi/storage-abi/interface-audit.json`
- `tools-wsl/run-native-ufs.sh [qemu|phone]` — 编 `NativeUfs.o` + 绑原版存储类，产 `tree/build/native-ufs/{libNativeUfs.a,bindings.json,build-report.json}`
- `tools-wsl/run-storage-providers.sh static|live [基名] [复用 ESP 档] [含 AES 元类读址的快照档]` — 静态段定位原版 IOAESAccelerator 派发表；活体段读三个元类后产 `libNativeAES.a` / `libNativeVirtioBlock.a`
- `tools-wsl/make-gdb-stop-sctlr-observer.py` — 产「别名观测件」，把本机 QEMU 的 `SCTLR` 双写成 `SCTLR_EL1`（上游审计脚本按精确名取值，否则判不出 native 4K）
- 作者的工具把候选内核名字写死（`qemu-storage-apfs.macho` / `qemu-native-ufs-trace.macho` + 同名 `.json`），本仓那件叫 `apfs-prelink-kernel.macho`；脚本按 audit 的 `candidate_sha256` 核对后落名/建链接，对不上就停手——别用过期 audit 去绑内核地址

### U 步之三：owner-root / VerifiedRoot 真根策略（纯 Linux）
- `tools-wsl/make-volume-infos-linux.py` — 产 `OS`/`SystemOS` 两枚 `*-volume-info.json`（`prepare_umi_root_policy.py` 唯一的输入，卷 UUID 从 GPT 分区起点上的 libfsapfs 视图读）
- `tools-wsl/verified-root-host-check-linux.py` — Linux 侧 host 自检，顶掉上游 Mac 的 `VerifiedRoot/tests/check.py`
- `tools-wsl/prepare-root-policy-linux.py` — 9.1 GiB 两窗逐块真验签，产 `policies.json` + 73,287,008 B manifest
- `tools-wsl/run-root-policy.sh` — 上面三件的总入口 + `build_umi_root_bundle.py`，产 `tree/build/umi-root-policy/libVerifiedRootProbe.a`
- `tools-wsl/run-kernel-owner-root.sh audit|trust` — `build_umi_xnu.py --stage kernel --profile qemu --crypto-bootstrap prelinked --native-ufs --owner-root <档> -j 5`
- `tools-wsl/run-owner-root-qemu.sh audit|trust [run名]` — prelink + `run_umi_qemu.py --root-volume` 取证，产物落 `out/umi-qemu/<run名>/`
- `tools-wsl/evaluate-owner-root-evidence.py RUN [audit|trust]` — 把官方 `check_umi_owner_root_qemu.py` 的 23 条断言逐条拆成 PASS/FAIL（断言集合不增减，别拿去当"我放宽了"的借口）
- 两档的停法不一样：audit 停 `_panic`（拒挂根是它的证据），trust 停 `_native_owner_root_accepted_checkpoint` 且必须带 `--finish`
- 还差一件才够官方一站式 PASS：`out/umi/screen-qemu-baseline.json`（要官方 screen-diagnostics 资格化链，本机完全没有）。trustcache 原件那件缺口已在本仓闭合，见下面 U 步之四

### U 步之四：trustcache 原件取源与 38 档取证（纯 Linux）
- `tools-wsl/fetch-ipsw-buildmanifest-linux.py` — 用上游 `unixnu.ipsw.RangeFile` 走 HTTP Range 只取远端 IPSW 的
  `BuildManifest.plist`（749,588 B，sha 命中 `devices/umi/ipsw-inputs.json` 的 `manifest_sha256`），不落整包
- `tools-wsl/run-original-trust-linux.sh` — 上面那件 + **官方 `tools/prepare_umi_trustcache.py` 一字未改**，
  产 `out/umi/trustcache/original-static-system.bundle`（61,356 B，sha `7416ca4f…`，官方件里 assert 钉死）+ `inputs.json`
- `tools-wsl/run-trustcache-qemu.sh [run名] [停点符号]` — `run_umi_qemu.py --trust-cache … --root-volume …` 跑到
  launchd 的 AMFI 信任缓存查询；`EXTRA_TRACE=1 FINISH=0 … _panic` 是探路跑法（把候选全挂 logpoint 看 lr 归属）
- `tools-wsl/evaluate-trustcache-evidence.py RUN` — 把官方 `check_umi_trustcache_qemu.py` 的 13 条断言逐条拆成 PASS/FAIL
- `tools-wsl/check-trustcache-official.sh` — **直接跑上游官方 check 件**（导出工具链 PATH 后可用），产
  `out/umi/trustcache-qemu-baseline.json`；本机实测 PASS，14/14
- **停点原理**：官方只要求最终 `pc` 落在 AMFI 的 `__TEXT_EXEC` extent 内，而 `--finish` 的 `pc` 是**调用方返回址**；
  donor AMFI 段里 `nm` 符号数 0，所以别去找「AMFI 内部地址」，要挑**被 AMFI 调用的内核符号**（`trust_cache`/`cs*` 面）
- **观测件通路**：`trace_events` 每条带 `pc/x0/x1/lr/elapsed_seconds`（`gdb-stop.py` 里两处 append 都是这个形状），
  所以一次跑就能按 `lr` 落在哪个段来判「谁调用了谁」，不需要静态反汇编
- 两个本机工具坑：`xcrun nm` 只在导出 `XNU_TOOLCHAIN_BIN` + 工具链 PATH 后可用（`/usr/bin/xcrun` 是 Linux shim，
  默认 PATH 下退化成 GNU `nm`，对 Mach-O 报 `file format not recognized`）；本机没有能按 VMA 反汇编 prelinked 件的
  objdump（GNU 不认这格式，`llvm-objdump -d` 只吃它自己认识的符号址区间）

### U 步之五：SystemOS union 与 dyld shared cache（进系统的那道闸）
- `tools-wsl/run-kernel-systemos.sh` — `build_umi_xnu.py --stage kernel --profile qemu --crypto-bootstrap prelinked
  --native-ufs --owner-root trust --systemos`；`--systemos` 要求 owner-root=trust，并打开
  `XNU_OWNER_CACHE_MOUNT/OWNER_CACHE_STARTUP/OWNER_BOOT_MANIFEST/OWNER_UNION_SYSTEMOS/NATIVE_CS_HASH_CACHE`
- `tools-wsl/h-wait-systemos-chain.sh` — 全链一条命令：等 kernel 构建结束 → 判 SystemOS 观测符号在位 →
  `run-umi-prelink.sh qemu-systemos-union`（`build_umi_prelink.py` **没有** systemos 开关，只 `--profile/--storage`）→
  QEMU 取证 → 官方 analyze；日志在 `out/probes/systemos-chain.log`
- `tools-wsl/run-systemos-qemu.sh [run名]` — 三旗标取证：`--root-volume --systemos-volume --trust-cache`，
  再把官方 analyze 要读的观测符号一个不缺地 `--read-symbol` 挂上（`_native_owner_cache_*` / `_umi_exec_trace_*` /
  `_cs_native4k_*` / `_initproc_spawned`），`--trace _trust_cache_runtime_init --trace _load_init_program`
- `tools-wsl/evaluate-systemos-evidence.py RUN` — 本地按官方 analyze 的断言集逐条拆 PASS/FAIL/BLOCKED
  （断言不增减）。39 档实测 **15/15 PASS，1 条 BLOCKED**
- 判读件是官方的 `tools/analyze_umi_systemos_qemu.py`（不是 check 件，它拒绝覆盖已有 analysis.json），
  它断言 `_native_owner_cache_status=0`/`authorized=1`/`native_union=1`、`_initproc_spawned=1`，
  并把结果分成 `launchd_main_and_services_observed_within_bounded_run` 等四档；
  `ios_ui_observed` 与 `phone_runtime_equivalence_proved` 在上游自己手里恒为 false。
  **它在第 59 行无条件 `read("_exit_records", 2382)`，本机内核没链这个符号 → `KeyError` 崩**；
  崩点本身证明 25–58 行的断言全过，剩下的用本地 evaluate 件补
- `run_umi_qemu.py --systemos-volume` 必须与 `--root-volume` 同给（它自己 error 出来），并会 SHA 校验第二个窗，
  两块只读盘分别落到 `virtio_block_input` / `virtio_extra_block_input`
- **原版卷实测（u151/u152/u154，纯 Linux 只读）**：OS 卷 `DawnUpdate21H461…OS` 里
  `/usr/lib/dyld`(937,056, `cf fa ed fe` filetype 7) 与 `/sbin/launchd`(561,856, filetype 2) 是实体文件，
  但 **`/usr/lib/libSystem.B.dylib` 不存在**（只有 `libSystem.B_asan.dylib`），
  `/System/Library/Caches/com.apple.dyld` 整个目录也不存在（`/System/Library/Caches` 只有 3 项）→
  屏上 `(no such file, no dyld cache)` 是字面正确，扩假根这条路本来就装不下
- **shared cache 在 SystemOS cryptex 窗里，且是明文**：该窗扫到 `dyld_v1` 65 次、`dyld_shared_cache` 253 次、
  `libSystem.B.dylib` 3,345 次、`com.apple.dyld` 70 次。libfsapfs 打不开这个卷的 B-tree
  （`invalid object type: 0x00000000`），但内核侧的原版 APFS 驱动不受这个限制——所以走 `--systemos-volume` 而不是主机解析
- pyfsapfs 的 `file_entry` 面**没有** `metadata`/`get_number_of_sub_entries`；正确用法是
  `vol.get_file_entry_by_path("/…")`（路径不存在返回 `None`，不是异常）+
  `entry.get_number_of_sub_file_entries()` / `get_sub_file_entry(i)` / `entry.size` / `entry.file_mode`
- **39-systemos-union 实测（2026-11-05，`out/screens/39-systemos-union.png`）**：cache 挂载与授权这半道闸过了——
  `(status, authorized, native_union) == (0,1,1)`、两窗 sha 命中官方钉值（OS `e5634d04…` / SystemOS `b4908cde…`）
  且区间不重叠、两块 virtio 盘只读且真挂上、`owner_root` 前六字段 `(2,1,80,1,1,1)`、`observation[0]==1`、
  `dyld_flags=8`、native 4K 哈希面 `full_blocks=30892 / page_checks=36 / ready_blobs=9`。
  屏上 `(no such file, no dyld cache)` **消失**，代之以 `EL0 IN/OUT svc=…` 流水（28/26/372/294/10/14/20/427…）；
  这批 EL0 是真件不是假根——本档 `mockfs_initrd=None`、内核里 mockfs 符号 0 个，
  行本身由 `osfmk/arm64/sleh.c:1957` 的内核侧 trap 观测件打印（对任何 EL0 进程都生效）
- **新的停点＝上游自己的终点**：`pc=0xfffffff00bffe6ac=_panic+0x0`，`x0` 指 `"AMFI: No PMGR?\n"`，
  调用栈是 `_thread_call_invoke+0x78` ← `_thread_call_thread+0x218` ← `_Call_continuation+0x44`（异步 thread call，
  `bounded_timeout_interrupted=False` 不是超时假象）；trace 两条 `_trust_cache_runtime_init`(7.841s) /
  `_load_init_program`(9.299s)，phase 位 `[1,3,4,6,10,11,16,17,32,33]`（16/17 与 32/33 = 两次 init_exec begin/return），
  但 `_initproc_spawned=0` → `launchd_main_observed=false`。**这正上游 check 件原话判死的形态**
  （`check-owner-dyld-startup-checkpoints.py:112` "full cache mapping, launchd main and hardware remain open"），
  所以下一步不是补作业，是要超出上游

### 真机（小米 10）
- `tools-win/fastboot-boot.cmd` — Windows 一键：选本地镜像 → 重启到 fastboot → `fastboot boot`（零写入）→ 1 分钟无设备自动回菜单
- `tools-wsl/collect-phone.sh` / `analyse-phone-capture.py` — 采集与判读
- 镜像与工具位置见下面「硬约束」

### 监控与进度
- `tools-wsl/launch-web.sh` — 装并后台起 8765 面板，自检 `/api/state`
- `tools-wsl/progress.sh` / `dashboard.sh` / `rawlog.sh` — 命令行侧速率、ETA、最近日志

## 产物放哪

`out/` 整目录 gitignore，不入库：`out/probes/`（取证，960+ 份）、`out/screens/`（屏照）、
`out/fixtures/`（容器件）、`out/images/`（真机档镜像）、`out/scratch/`。
临时实验放 `out/scratch/`，别往 `tools-wsl/` 根上再堆一次性脚本。

## 进度到哪了（2026-11-05）

- ✅ Linux host 工具链、host 校验、内核基线（QEMU 验过）
- ✅ umi UEFI 菜单包 + 真机 `fastboot boot` 出菜单（`MuPatches` 必须 CRLF）
- ✅ crypto kit 注册，过 `generatePlatformUUID` 的 `g_crypto_funcs` 闸
- ✅ mockfs RAM 根挂根（真机闸是漏了 `--mockfs-root`，不是驱动问题）
- ✅ EL0 走查面：23 发 syscall + Mach trap 面 9 发 + vm/port 面 4 发，真机与 QEMU 逐字节同源，拿到真 send right
- ✅ 30z：`ubc_subr.c` 两处裸 `amfi->` 补 NULL 守卫（`_amfi` 在本构建恒 NULL），二进制层 GUARD-OK
- ✅ **T 步里程碑**：`run-41-real` 里内核侧签名链全过、真 launchd 被 exec、真 dyld 跑起来
- ✅ **U 步之一**：prelink 开 storage 根，原版 APFS 在 QEMU 里 `vfs_fsadd` 返回 0（注册成功）
- ✅ **U 步之二（资格化）**：storage ABI 活体审计出 `interface-audit.json`；`NativeUfs` 绑定过
  （190 槽 / 23 覆写 / 11 真原版导入）；`storage providers` 过（AES 181 槽 + 22 条原生绑定，
  VirtIO 与 UFS 共用同一套原版类别名）→ `libNativeUfs.a` / `libNativeAES.a` / `libNativeVirtioBlock.a`
- ✅ **U 步之三（owner-root 子链结案）**：Linux 侧产出 VerifiedRoot 策略 → `audit`/`trust` 两档内核
  → QEMU `--root-volume` 只读挂真 APFS 根，官方 23 条断言 **两档各 23/23 全过**。
  屏上硬证据：`vfs_mountroot enter` → `vfs_mountroot mounted; authentication pending` → `calling VFS_ROOT`；
  18 字段里 `apple_autherr=80`(EAUTH)、`owner_decision=readonly=1`、三设备号同 `0x1000003`、
  `provider_depth=9`、`virtio 已验块 329`、audit `phase=1 accepted=0` / trust `phase=2 accepted=1`
- ✅ **U 步之四（trustcache 原件 + 38 档结案）**：Linux 侧 Range 取 `BuildManifest.plist` → 官方
  `prepare_umi_trustcache.py` 一字未改产 `original-static-system.bundle`（sha `7416ca4f…`）→
  `qemu-trustcache-runtime.macho`（sha `b11d3148…`）+ `--trust-cache --root-volume` 停
  `_query_trust_cache --finish`，**官方 `check_umi_trustcache_qemu.py` 本机直接跑出 PASS**，
  产 `out/umi/trustcache-qemu-baseline.json`（`query_return=0`、`returned_to_original_amfi=true`、
  `root_owner_accepted=true`、`user_program_load_reached=true`、`el0_execution_proved=false`）。
  屏上硬证据：`SETCONF rootdev=0x1000003 rd=disk1s1` → `vfs_mountroot mounted` → `calling VFS_ROOT` →
  `root authentication decision recorded` → `bsd_init: done` → `load_init_program enter` →
  `INIT try /sbin/launchd` → REAP 六发全 ok → `drivers 1 loaded / 0 failed`
- ✅ **原版卷取证结案（u151/u152/u154）**：OS 卷里 `dyld`/`launchd` 是实体文件，但 `libSystem.B.dylib`
  与 `com.apple.dyld` 目录**都不存在**；shared cache 明文躺在 SystemOS cryptex 窗里（`dyld_v1` 65 次命中）。
  所以「进系统」的正解是上游的 `--systemos` 档，不是往假根里塞文件
- ✅ **U 步之五（SystemOS union / dyld shared cache）**：Linux 侧 `--systemos` 档内核 → `qemu-systemos-union.macho`
  （sha `5fbddad6…`，17 件 / virtual_span 140,681,216 / owned_memory 335,544,320）→ 三窗只读盘 QEMU 取证。
  **官方 analyze 件能评的断言 15/15 全过**（`_exit_records` 那条 BLOCKED，见下），屏上
  `(no such file, no dyld cache)` 消失，`(status,authorized,native_union)=(0,1,1)`、cache 授权与 native 4K 哈希面全绿
- 🔴 **当前闸（两个独立缺口）**：
  ① `launchd_main_observed=false`——两次 init-exec 都返回但 `_initproc_spawned=0`，停点是异步 AMFI
  `"AMFI: No PMGR?"` panic；**上游自己也停在这里**（原话判词见 U 步之五末条），要归因的是 launchd 的 exec 为何没落成 initproc；
  ② 官方一站式 `analysis.json` 跑不全——`analyze_umi_systemos_qemu.py:59` 无条件读 `_exit_records`，
  该符号只在 `--screen-diagnostics`（它又硬要求 `--gic-diagnostics`）档里链进内核，本机八档内核全都 `exit_records=0`。
  这同一件也挡住了 U 步之三留的 `out/umi/screen-qemu-baseline.json`：**补这一档同时闭合两条腿**
- ℹ️ Mac VM：本轮不用、也别删。Linux 侧已顶掉 AEA 解密、`dwarfdump/nm` 与官方 trustcache 资格化；
  唯一残留缺口是「往 APFS 卷写文件」（`apfsprogs` 无写文件工具，`apfs-dkms` 已装未编，本树 `bsd/miscfs/` 无 APFS 驱动）

## 硬约束（用户原话级，不要重新征询）

- **装 D 盘，不要放 C**；本机 Ryzen5 6c12t/32GB，大构建放 D:
- **回复保持简短**，全程中文；结尾标明是纯汇报还是要用户动手/拍板
- **未经明确确认，不得对手机分区做任何写入/刷机**；`fastboot boot` 属零写入、已获授权
- 手机已连好，可以直接操作；需要从手机取信息也可以
- **阶段性改动推 `https://github.com/keno80/hackios-umi`**；新功能先开分支，完成后合并回 main
- **调试日志与线索不进 git**；本仓 git 身份：`keno80` / `1211582428@qq.com`
- 镜像位置 `C:\Users\admin\Desktop\phone-capture`，platform-tools 在 `E:\Android\SDK\platform-tools`
- 长任务要主动播报进度；能自测的全自己测；闭环自己做完（合并/推送直接执行，破坏性操作单独问）

## 别碰 / 别信

- `tools-wsl/attic/` — 613 份一次性探针归档，别引用、别当入口；顶层只剩 99 个规范脚本（外加 2 份 `umi_*_tail.c`）
- `/usr/local/bin` 里除 `sync-helpers.sh` 白名单那 7 个之外的命令 — 都是早年全量快照的历史残留，改仓库脚本不会生效；要清就跑 `reboot-restore.sh --prune`
- `unixnu-logs/latest.txt` 指向的是 11-02 的失败 bootstrap 日志；最近内核构建看 `kernel-walk-latest.txt`
- `tNN-` / `sNN-` / `run-NN` 这类序号名脚本是归档命名，新脚本用「步名-语义名」（如 `make-amfi-guard-patch.py`）
- 直接编辑 `.cache/xnu-work` 下的源——构建会还原抹掉，必须落成 `patches/umi-xnu/` 补丁

## 本树踩过的码值坑（省几小时）

- `EXTERNAL_HEADERS/mach-o/loader.h`：本树 `MH_DYLINKER = 0x7`（不是常见 0x6），`LC_LOAD_DYLINKER=0xe`，`LC_CODE_SIGNATURE=0x1d`（0x1b 是 LC_UUID）
- `lc_str` 偏移**相对本条 load command 起点**，不是段首
- 代码签名结构是**网络序（大端）**；CDHash = 对第一张 CodeDirectory 的 `cdlen` 字节做摘要
- `CODE_SIGNING_MONITOR` 在本构建走 `#else` 分支 = 0（无 ppl/txm），所以 `#if CODE_SIGNING_MONITOR` 的段被编掉
- `kern_return` / Mach 返回码编号与本树一致，别按 BSD 直觉填
- **本机 QEMU 8.2.2 的 gdbstub 把 EL1 控制寄存器登记为 `SCTLR`（regnum 150），不是 `SCTLR_EL1`**；
  上游 `gdb-stop.py` 按精确名收，`MIDR_EL1` 本机也不存在 → 用 `make-gdb-stop-sctlr-observer.py`
  的别名观测件把同一个值**双写**成两个键，别改 audit 脚本的判据
- 「native 4K」三位判据实测值：`TCR_EL1=0x22a51a251a`（`>>14&3==0` 是 TG0、`>>30&3==2` 是 TG1）、
  `SCTLR_EL1=0x3454593d`（bit0=M=1）、`TTBR0=0x4c0a8000`/`TTBR1=0x4c0a9000`
- OSMetaClass 对象内 `+16 = superClassLink`、`+32 = classSize`（IOAESAccelerator 元类 classSize=`0x120`，
  IOService=`0x88`）；快照读址长度必须给 `0x50`（80 字节），audit 里 `length>=40/0x50` 两种都出现过
- **`run_umi_qemu.py --stop` 的符号名要带 Mach-O 前导下划线**（它的 `symbol()` 直接吃 `xcrun nm -n` 第 3 列原名）；
  少了下划线是 `error: missing exact kernel symbol`，且失败发生在建 run 目录之前，不会留空档挡住重跑
- `gdb-stop.json` 的 `function_return_stack_matched` / `function_entry_arguments` **只在带 `--finish-function` 时写**；
  上游 `check_umi_owner_root_qemu.py` 那两条断言在纯 `--stop` 档里必然取不到键
- `--root-volume` 不需要别名观测件：`run_umi_qemu.py` 在 `accel=="tcg"` 时自动追加 `--system-registers`，
  默认件已带 `TCR_EL1`/`TTBR0_EL1`/`SCTLR_EL1`（本机 QEMU 只有 `SCTLR` 那个登记名要双写）
- `memory` 键格式是 `<地址:#x>:<长度十六进制>`（`_umi_owner_root_observation` 的 18 个 `Q` 就是 `:90`）；
  `--read-symbol NAME:LEN` 的 LEN 直接写十六进制字节数
- `--crypto-bootstrap prelinked` 的 kernel 步把产物**直接**写成 `kernel/qemu-prelink-source-kernel.macho`
  （不是 `source-kernel.macho`，构建自己的 status JSON 里 `kernel` 字段就是它），所以每编一档覆盖一次；
  `run-umi-prelink.sh` 写死吃它 → 各档 prelink 产物 sha 不同（audit `58f2840b…` / trust `b11d3148…` /
  systemos `5fbddad6…`），**编完一档立刻 prelink + 取证**，别拿过期输入件去跑另一档
- **判内核符号在位只能用 cctools 那份 `nm`（`$TC/CommandLineTools/usr/bin/nm`）**：本机
  `/opt/unixnu-linux/CommandLineTools/usr/bin/llvm-nm` **不存在**，配 `2>/dev/null` 时 `command not found`
  被吞掉、`grep -c` 恒 0，会把「全都在」静默判成「全都缺」（`h-wait-systemos-chain.sh` 被这坑停手过一次）。
  现在该件先 `[ -x "$NM" ]` 硬闸，再打印 `nm 符号行数`，空 dump 不可能冒充结果
- **`_exit_records` 不是内核符号，是 `devices/umi/package/boot-progress/BootProgress.c` 里的 `static`**
  （`static struct bp_exits exit_records,exit_snapshot;`），只有 `--screen-diagnostics` 档才链进内核，
  而 `--screen-diagnostics` 又硬要求 `--gic-diagnostics`。所以 `--read-symbol _exit_records:…` 会让
  `run_umi_qemu.py` 在建 run 目录前就 `missing exact kernel symbol` 全档失败；官方
  `analyze_umi_systemos_qemu.py:59` 无条件读它，本机八档内核 `exit_records=0` → 该件必然 `KeyError`
