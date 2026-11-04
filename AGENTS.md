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
- 还差两件才够官方一站式 PASS：`out/umi/screen-qemu-baseline.json`（要官方 screen-diagnostics 资格化链，本机完全没有）和 `--systemos` 要的 trustcache 原件（sha `7416ca4f…`，本机两枚 per-volume 件是 `9742f3d5…`/`4563bdbf…`，不是它）

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

## 进度到哪了（2026-11-04）

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
- 🔴 **当前闸**：屏上 `Library not loaded: /usr/lib/libSystem.B.dylib`（marks=3351）。两槽假根装不下系统库，
  已判死「扩假根」；owner-root 已通，下一步是 `--systemos` + `--systemos-volume` + `--trust-cache`
- ℹ️ Mac VM：本轮不用、也别删。Linux 侧已顶掉 AEA 解密与 `dwarfdump/nm`；唯一残留缺口是「往 APFS 卷写文件」（`apfsprogs` 无写文件工具，`apfs-dkms` 已装未编，本树 `bsd/miscfs/` 无 APFS 驱动）

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
  `run-umi-prelink.sh` 写死吃它 → 两档 prelink 产物 sha 不同（audit `58f2840b…` / trust `b11d3148…`），
  **编完一档立刻 prelink + 取证**，别拿过期输入件去跑另一档
