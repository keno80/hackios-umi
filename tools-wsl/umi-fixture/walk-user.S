// SPDX-License-Identifier: BSD-2-Clause-Patent
// UMI walk fixture: 上游 native-user.S 的判据偏移一字不动（_results/_user_page_size/_old_length），
// 在其后追加 _walk/_nz 走查区，让 PID 1 依次打一组真 unix syscall。
// 号表取自本树生成的 bsd/sys/syscall.h（build/xnu/ios-obj/EXPORT_HDRS，别凭记忆写）：
//   exit=1 fork=2 read=3 write=4 open=5 close=6 wait4=7 getpid=20 getppid=39
//   umask=60 madvise=75 munmap=73 mprotect=74 pipe=42 dup2=90 fcntl=92
//   gettimeofday=116 getrusage=117 stat64=338 mmap=197 sysctl=202
//   kqueue=362 kevent=363 issetugid=327
// Mach 面（R 步起）号表取自本树 osfmk/kern/syscall_sw.c 的 mach_trap_table[]，x16 用负号：
//   task_self=-28 host_self=-29 thread_self=-27 mach_reply=-26 timebase_info=-89
//   port_allocate=-16 port_mod_refs=-19 port_deallocate=-18 mach_msg=-31
// S 步补的 Mach 面（实参顺序取自本树 osfmk/mach/mach_traps.h 的原型）：
//   vm_allocate=-10 vm_protect=-14 port_insert_right=-21 vm_deallocate=-12
//   注意本树 mach/port.h:270 的 MACH_PORT_RIGHT_SEND/RECEIVE 是 0/1（不是 Darwin 记忆的 -1/-2），
//   kern_return.h:151 的 17 是 KERN_INVALID_RIGHT（KERN_INVALID_CAPABILITY 在本树是 20）。
.text
.global _start, _checkpoint
_start:
  adrp x19, _results@PAGE
  add x19, x19, _results@PAGEOFF

  // [0] getpid —— 上游判据：_results[0]=pid
  mov x16, #20
  svc #0x80
  str x0, [x19]
  mrs x9, nzcv
  str x9, [x19, #16]

  // [1] sysctl(CTL_HW, HW_PAGESIZE) —— 上游判据：_results[1]、_user_page_size、_old_length
  adrp x0, _mib@PAGE
  add x0, x0, _mib@PAGEOFF
  mov x1, #2
  adrp x2, _user_page_size@PAGE
  add x2, x2, _user_page_size@PAGEOFF
  adrp x3, _old_length@PAGE
  add x3, x3, _old_length@PAGEOFF
  mov x4, #0
  mov x5, #0
  mov x16, #202
  svc #0x80
  str x0, [x19, #8]
  mrs x9, nzcv
  str x9, [x19, #24]

  adrp x19, _walk@PAGE
  add x19, x19, _walk@PAGEOFF
  adrp x22, _nz@PAGE
  add x22, x22, _nz@PAGEOFF

  // [2] getppid
  mov x16, #39
  svc #0x80
  str x0, [x19, #0]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #0]

  // [3] gettimeofday(&tv, NULL, &mat)
  adrp x0, _tv@PAGE
  add x0, x0, _tv@PAGEOFF
  mov x1, #0
  adrp x2, _mat@PAGE
  add x2, x2, _mat@PAGEOFF
  mov x16, #116
  svc #0x80
  str x0, [x19, #8]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #8]

  // [4] getrusage(RUSAGE_SELF, &ru)
  mov x0, #0
  adrp x1, _ru@PAGE
  add x1, x1, _ru@PAGEOFF
  mov x16, #117
  svc #0x80
  str x0, [x19, #16]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #16]

  // [5] open("/nonexistent", O_RDONLY) —— 期望失败，验错误路径与 errno/carry
  adrp x0, _p_none@PAGE
  add x0, x0, _p_none@PAGEOFF
  mov x1, #0
  mov x2, #0
  mov x16, #5
  svc #0x80
  str x0, [x19, #24]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #24]

  // [6] open("/launchd", O_RDONLY) —— 期望拿到 fd，验 mockfs 文件面
  adrp x0, _p_launchd@PAGE
  add x0, x0, _p_launchd@PAGEOFF
  mov x1, #0
  mov x2, #0
  mov x16, #5
  svc #0x80
  str x0, [x19, #32]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #32]
  mov x20, x0

  // [7] read(fd, &buf, 32) —— 期望 >0，验 exec 之外的第一个真读
  mov x0, x20
  adrp x1, _rbuf@PAGE
  add x1, x1, _rbuf@PAGEOFF
  mov x2, #32
  mov x16, #3
  svc #0x80
  str x0, [x19, #40]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #40]

  // [8] close(fd)
  mov x0, x20
  mov x16, #6
  svc #0x80
  str x0, [x19, #48]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #48]

  // [9] stat64("/dev") —— 验 devfs mountpoint 的 lookup 面
  adrp x0, _p_dev@PAGE
  add x0, x0, _p_dev@PAGEOFF
  adrp x1, _st@PAGE
  add x1, x1, _st@PAGEOFF
  mov x16, #338
  svc #0x80
  str x0, [x19, #56]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #56]

  // [10] fork —— 验进程面；子进程立刻 exit(0)，父进程记 pid
  mov x16, #2
  svc #0x80
  str x0, [x19, #64]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #64]
  cbz x0, _child
  mov x21, x0

  // [11] wait4(child, &status, 0, NULL) —— 只有父进程走
  mov x0, x21
  adrp x1, _wstatus@PAGE
  add x1, x1, _wstatus@PAGEOFF
  mov x2, #0
  mov x3, #0
  mov x16, #7
  svc #0x80
  str x0, [x19, #72]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #72]

  // ==== Q 步二期：fd / vm / event 面（只有父进程走）====

  // [12] pipe() —— 这棵树里它没有内存出参：master 写的是 `{ int pipe(void); }`，
  //      成功时 arm_prepare_u64_syscall_return 把 rval[0]→x0(读端)、rval[1]→x1(写端)。
  mov x16, #42
  svc #0x80
  str x0, [x19, #80]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #80]
  mov x20, x0
  mov x21, x1

  // [13] write(wfd, _wmsg, 24) —— 先写后读，避免 read 阻塞把后面全憋住
  mov x0, x21
  adrp x1, _wmsg@PAGE
  add x1, x1, _wmsg@PAGEOFF
  mov x2, #24
  mov x16, #4
  svc #0x80
  str x0, [x19, #88]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #88]

  // [14] read(rfd, _pibuf, 24) —— 期望 24，验真回环
  //      write 失败（carry=1）时绝不能读：读端没数据会永久阻塞，整条走查就冻在内核态（run-28 就是这么栽的）
  b.cs _after_read
  mov x0, x20
  adrp x1, _pibuf@PAGE
  add x1, x1, _pibuf@PAGEOFF
  mov x2, #24
  mov x16, #3
  svc #0x80
  str x0, [x19, #96]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #96]
_after_read:

  // [15] dup2(rfd, 100) —— 期望 100
  mov x0, x20
  mov x1, #100
  mov x16, #90
  svc #0x80
  str x0, [x19, #104]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #104]

  // [16] fcntl(rfd, F_GETFD) —— 期望 0
  mov x0, x20
  mov x1, #1
  mov x16, #92
  svc #0x80
  str x0, [x19, #112]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #112]

  // [17] mmap(NULL, 16384, RW, PRIVATE|ANON, -1, 0) —— 第一发真 vm_map 操作
  mov x0, #0
  mov x1, #16384
  mov x2, #3
  mov x3, #0x1002
  mov x4, #-1
  mov x5, #0
  mov x16, #197
  svc #0x80
  str x0, [x19, #120]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #120]
  mov x23, x0

  // [18] mprotect(addr, 4096, PROT_READ) —— 改权限，验 pmap 面
  mov x0, x23
  mov x1, #4096
  mov x2, #1
  mov x16, #74
  svc #0x80
  str x0, [x19, #128]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #128]

  // [19] madvise(addr, 4096, MADV_NORMAL) —— vm  Advice 面
  mov x0, x23
  mov x1, #4096
  mov x2, #0
  mov x16, #75
  svc #0x80
  str x0, [x19, #136]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #136]

  // [20] munmap(addr, 16384) —— 拆掉，验 vm 生命周期收尾
  mov x0, x23
  mov x1, #16384
  mov x16, #73
  svc #0x80
  str x0, [x19, #144]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #144]

  // [21] kqueue() —— 事件面入口
  mov x16, #362
  svc #0x80
  str x0, [x19, #152]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #152]
  mov x24, x0

  // [22] kevent(kq, NULL, 0, NULL, 0, &ts0) —— 零超时轮询，期望 0 且不阻塞
  mov x0, x24
  mov x1, #0
  mov x2, #0
  mov x3, #0
  mov x4, #0
  adrp x5, _ts@PAGE
  add x5, x5, _ts@PAGEOFF
  mov x16, #363
  svc #0x80
  str x0, [x19, #160]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #160]

  // [23] issetugid() —— 期望 0
  mov x16, #327
  svc #0x80
  str x0, [x19, #168]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #168]

  // [24] umask(022) —— 返回值是旧掩码，验 cred 面（LLVM 汇编里前导 0 不是八进制，18 == 0o22）
  mov x0, #18
  mov x16, #60
  svc #0x80
  str x0, [x19, #176]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #176]

  // ==== R 步三期：Mach trap 面 ====
  // 号表取自本树 osfmk/kern/syscall_sw.c 的 mach_trap_table[]（MACH_TRAP_TABLE_COUNT=128）。
  // mach 侧的 x16 是负数：bsd_arm64.c 的 mach_syscall() 里 call_number = -x16，>=128 直接判非法，
  // 所以这里只打表里真实存在的号。64 位下参数就是 x0..x(arg_count-1) 直取（arm_get_mach_syscall_args）。
  // 每一发都先确认过不阻塞：0 参的四个 port trap 只造 right；timebase 只 copyout 8 字节；
  // mach_msg 的 option=0 既不落 SEND 也不落 RCV 分支，内核立刻返回。

  // [25] task_self_trap(-28) —— 返回自己的 task port，后面 port_* 都拿它当 target
  mov x16, #-28
  svc #0x80
  str x0, [x19, #184]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #184]
  mov x25, x0

  // [26] host_self_trap(-29) —— host port；真机/ QEMU 上内核有没有 host 端口，这一发给答案
  mov x16, #-29
  svc #0x80
  str x0, [x19, #192]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #192]

  // [27] thread_self_trap(-27)
  mov x16, #-27
  svc #0x80
  str x0, [x19, #200]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #200]

  // [28] mach_reply_port(-26) —— launchd 收 RPC 回复全靠它
  mov x16, #-26
  svc #0x80
  str x0, [x19, #208]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #208]

  // [29] mach_timebase_info_trap(-89) —— 出参 numer/denom 两个 32 位字
  adrp x0, _tb@PAGE
  add x0, x0, _tb@PAGEOFF
  mov x16, #-89
  svc #0x80
  str x0, [x19, #216]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #216]

  // [30] mach_port_allocate(-16)(task, MACH_PORT_RIGHT_RECEIVE=1, &_pname) —— 第一次真造一个 port
  mov x0, x25
  mov x1, #1
  adrp x2, _pname@PAGE
  add x2, x2, _pname@PAGEOFF
  mov x16, #-16
  svc #0x80
  str x0, [x19, #224]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #224]
  adrp x26, _pname@PAGE
  add x26, x26, _pname@PAGEOFF

  // [31] mach_port_mod_refs(-19)(task, name, MACH_PORT_RIGHT_SEND=0, +1) —— 给自己加一个 send right
  mov x0, x25
  ldr w1, [x26]
  mov x2, #0
  mov x3, #1
  mov x16, #-19
  svc #0x80
  str x0, [x19, #232]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #232]

  // [32] mach_port_deallocate(-18)(task, name) —— 把刚加的 send right 退掉，验权利生命周期收尾
  mov x0, x25
  ldr w1, [x26]
  mov x16, #-18
  svc #0x80
  str x0, [x19, #240]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #240]

  // [33] mach_msg_trap(-31)(msg, option=0, 0, 0, 0, 0, 0) —— 通道本身通不通；option=0 保证不阻塞
  adrp x0, _msg@PAGE
  add x0, x0, _msg@PAGEOFF
  mov x1, #0
  mov x2, #0
  mov x3, #0
  mov x4, #0
  mov x5, #0
  mov x6, #0
  mov x16, #-31
  svc #0x80
  str x0, [x19, #248]
  mrs x9, nzcv
  orr x9, x9, #0x100 // executed 标记位：返回 0 也能和「没跑到」区分
  str x9, [x22, #248]

  // ---- S 步：vm 面三发 + 端口权利补全。号都取自 syscall_sw.c 的 mach_trap_table，
  //      实参顺序取自 osfmk/mach/mach_traps.h 的原型（64 位下参数就是 x0..x(n-1)）。
  // [34] _kernelrpc_mach_vm_allocate_trap(-10)(target, mach_vm_offset_t *addr, size, flags)
  //      flags=VM_FLAGS_ANYWHERE(1)；出参是 8 字节的 mach_vm_offset_t，不是 4 字节。
  mov x0, x25
  adrp x1, _vmaddr@PAGE
  add x1, x1, _vmaddr@PAGEOFF
  mov x2, #0x4000
  mov x3, #1
  mov x16, #-10
  svc #0x80
  str x0, [x19, #256]
  mrs x9, nzcv
  orr x9, x9, #0x100
  str x9, [x22, #256]
  adrp x27, _vmaddr@PAGE
  add x27, x27, _vmaddr@PAGEOFF

  // [35] _kernelrpc_mach_vm_protect_trap(-14)(target, address, size, set_maximum, new_protection)
  //      new_protection=VM_PROT_READ|VM_PROT_WRITE=3
  mov x0, x25
  ldr x1, [x27]
  mov x2, #0x4000
  mov x3, #0
  mov x4, #3
  mov x16, #-14
  svc #0x80
  str x0, [x19, #264]
  mrs x9, nzcv
  orr x9, x9, #0x100
  str x9, [x22, #264]

  // [36] _kernelrpc_mach_port_insert_right_trap(-21)(target, name, poly, polyPoly)
  //      标准写法是 poly == name（本树 port.h 注 MACH_MSG_TYPE_MAKE_SEND「Must hold receive right」，
  //      [30] 的 receive right 就在 name 里）。poly=0 是 MACH_PORT_NULL，内核直接按名字查不到，
  //      实测回 0xf=KERN_INVALID_NAME（本树 kern_return.h:143）——那是用法错的正确拒绝，不是闸。
  mov x0, x25
  ldr w1, [x26]
  ldr w2, [x26]
  mov x3, #20
  mov x16, #-21
  svc #0x80
  str x0, [x19, #272]
  mrs x9, nzcv
  orr x9, x9, #0x100
  str x9, [x22, #272]

  // [37] _kernelrpc_mach_vm_deallocate_trap(-12)(target, address, size) —— 收尾，验回退路径
  mov x0, x25
  ldr x1, [x27]
  mov x2, #0x4000
  mov x16, #-12
  svc #0x80
  str x0, [x19, #280]
  mrs x9, nzcv
  orr x9, x9, #0x100
  str x9, [x22, #280]
  b _checkpoint

_child:
  mov x0, #0
  mov x16, #1
  svc #0x80
  b _checkpoint

_checkpoint:
  b _checkpoint
.data
.balign 8
.global _results, _user_page_size, _old_length
_results:
  .quad 0, 0, 0, 0
_mib:
  .word 6, 7 // CTL_HW, HW_PAGESIZE from Darwin 23 sys/sysctl.h
_user_page_size:
  .quad 0
_old_length:
  .quad 8
.balign 16
.global _walk, _nz
_walk:
  .quad 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .quad 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .quad 0, 0, 0, 0, 0, 0, 0, 0
_nz:
  .quad 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .quad 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .quad 0, 0, 0, 0, 0, 0, 0, 0
_wmsg:
  .ascii "UMI-WALK-Q-PIPE-PAYLOAD"
  .byte 0
_stag:
  .ascii "UMI-WALK-S-VM-PAYLOAD"   // S 步件身份标记：出图闸靠它挡住「内核新但件还是 R 版」
  .byte 0
_pibuf:
  .space 64
_ts:
  .quad 0, 0
_tv:
  .quad 0, 0, 0, 0
_mat:
  .quad 0
_ru:
  .space 256
_st:
  .space 256
_rbuf:
  .space 64
_wstatus:
  .word 0, 0
_tb:
  .quad 0          // mach_timebase_info_data_t：numer/denom 各 32 位
_pname:
  .long 0, 0       // mach_port_allocate 的出参（mach_port_name_t = 32 位）
.balign 8
_vmaddr:
  .quad 0          // vm_allocate 的出参（mach_vm_offset_t = 64 位）
.balign 16
_msg:
  .space 64        // mach_msg 的缓冲区；option=0 时内核不会碰它，给个合法地址只为稳妥
_p_none:
  .asciz "/nonexistent"
_p_launchd:
  .asciz "/launchd"
_p_dev:
  .asciz "/dev"
