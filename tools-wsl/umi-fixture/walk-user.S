// SPDX-License-Identifier: BSD-2-Clause-Patent
// UMI walk fixture: 上游 native-user.S 的判据偏移一字不动（_results/_user_page_size/_old_length），
// 在其后追加 _walk/_nz 走查区，让 PID 1 依次打一组真 unix syscall。
// 号表取自本树生成的 bsd/sys/syscall.h（build/xnu/ios-obj/EXPORT_HDRS，别凭记忆写）：
//   exit=1 fork=2 read=3 write=4 open=5 close=6 wait4=7 getpid=20 getppid=39
//   umask=60 madvise=75 munmap=73 mprotect=74 pipe=42 dup2=90 fcntl=92
//   gettimeofday=116 getrusage=117 stat64=338 mmap=197 sysctl=202
//   kqueue=362 kevent=363 issetugid=327
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
_nz:
  .quad 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
  .quad 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
_wmsg:
  .ascii "UMI-WALK-Q-PIPE-PAYLOAD"
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
_p_none:
  .asciz "/nonexistent"
_p_launchd:
  .asciz "/launchd"
_p_dev:
  .asciz "/dev"
