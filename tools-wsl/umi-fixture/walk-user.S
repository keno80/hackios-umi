// SPDX-License-Identifier: BSD-2-Clause-Patent
// UMI walk fixture: 上游 native-user.S 的判据偏移一字不动（_results/_user_page_size/_old_length），
// 在其后追加 _walk/_nz 走查区，让 PID 1 依次打一组真 unix syscall。
// 号表来自 bsd/kern/syscalls.master（老 BSD 编号）：
//   exit=1 fork=2 read=3 open=5 close=6 wait4=7 getpid=20 getppid=39
//   gettimeofday=116 getrusage=117 stat64=338 sysctl=202
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
  str x9, [x22, #8]

  // [4] getrusage(RUSAGE_SELF, &ru)
  mov x0, #0
  adrp x1, _ru@PAGE
  add x1, x1, _ru@PAGEOFF
  mov x16, #117
  svc #0x80
  str x0, [x19, #16]
  mrs x9, nzcv
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
  str x9, [x22, #40]

  // [8] close(fd)
  mov x0, x20
  mov x16, #6
  svc #0x80
  str x0, [x19, #48]
  mrs x9, nzcv
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
  str x9, [x22, #56]

  // [10] fork —— 验进程面；子进程立刻 exit(0)，父进程记 pid
  mov x16, #2
  svc #0x80
  str x0, [x19, #64]
  mrs x9, nzcv
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
  str x9, [x22, #72]
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
_nz:
  .quad 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
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
