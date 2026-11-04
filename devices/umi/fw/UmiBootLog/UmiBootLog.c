/** @file
  Read the umi console ramoops ring and show boot markers on screen.

  Firmware DebugLib writes to RamoopsSerialPortLib, a Linux-compatible ring at
  0xB0000000 (12-byte header, no ECC, capacity 0x1FFFF4). DarwinBoot runs in
  APRIORI before ConOut exists, so its checkpoints only ever land there, and a
  later boot appends to the same ring instead of clearing it. This reader keeps
  the newest lines that carry a marker, which may come from an earlier attempt,
  and shows the newest lines as a control.

  The "UMI XNU" needle catches umi_early_trace() records from a kernel built
  with --early-trace. Those are the only milestones that exist before
  arm_vm_init(), where the framebuffer painter cannot map anything yet.

  SPDX-License-Identifier: BSD-2-Clause-Patent
**/

#include <Uefi.h>
#include <Library/BaseLib.h>
#include <Library/BaseMemoryLib.h>
#include <Library/UefiApplicationEntryPoint.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/UefiLib.h>

#define RING_BASE       0xB0000000ULL
#define RING_BYTES      0x00200000U
#define RING_HEADER     12U
#define RING_CAPACITY   (RING_BYTES - RING_HEADER)
#define RING_SIGNATURE  0x43474244U
#define MAX_LINE        140U
#define MAX_MATCH       48U
#define MATCH_SHOW      32U
#define MAX_TAIL        10U
#define TAIL_SHOW       8U

// The kernel's RAM-console markers are emitted by umi_early_trace() as
// "UMI XNU <phase> <value>"; they are the only evidence available before
// arm_vm_init(), where the framebuffer painter cannot run yet.
STATIC CONST CHAR8  *mNeedles[] = { "UMI XNU", "DARWINBOOT" };
#define NEEDLE_COUNT (sizeof (mNeedles) / sizeof (mNeedles[0]))
STATIC CHAR8        mMatchText[MAX_MATCH][MAX_LINE + 1];
STATIC UINT32       mMatchCount;
STATIC UINT32       mMatchHead;
STATIC CHAR8        mTailText[MAX_TAIL][MAX_LINE + 1];
STATIC UINT32       mTailCount;
STATIC UINT32       mTailHead;
STATIC CHAR8        mLine[MAX_LINE + 1];

STATIC
VOID
Remember (
  IN OUT CHAR8   Table[MAX_TAIL][MAX_LINE + 1],
  IN OUT UINT32  *Count,
  IN OUT UINT32  *Head,
  IN UINT32       Limit
  )
{
  if (*Count < Limit) {
    CopyMem (Table[*Count], mLine, AsciiStrLen (mLine) + 1);
    (*Count)++;
    return;
  }

  CopyMem (Table[*Head], mLine, AsciiStrLen (mLine) + 1);
  *Head = (*Head + 1) % Limit;
}

STATIC
BOOLEAN
LineMatches (
  VOID
  )
{
  UINTN  Length = AsciiStrLen (mLine);
  UINTN  Needle;
  UINTN  Index;
  UINTN  Probe;

  for (Probe = 0; Probe < NEEDLE_COUNT; Probe++) {
    Needle = AsciiStrLen (mNeedles[Probe]);
    if (Length < Needle) {
      continue;
    }

    for (Index = 0; Index + Needle <= Length; Index++) {
      if (AsciiStrnCmp (&mLine[Index], mNeedles[Probe], Needle) == 0) {
        return TRUE;
      }
    }
  }

  return FALSE;
}

STATIC
VOID
WaitKey (
  IN UINTN  Microseconds
  )
{
  UINTN  Ticks = Microseconds / 100000;

  if ((gST->ConIn == NULL) || (gST->ConIn->WaitForKey == NULL)) {
    gBS->Stall ((UINTN)Microseconds);
    return;
  }

  while (Ticks-- > 0) {
    gBS->Stall (100000);
    if (!EFI_ERROR (gBS->CheckEvent (gST->ConIn->WaitForKey))) {
      gST->ConIn->ReadKeyStroke (gST->ConIn, NULL);
      return;
    }
  }
}

EFI_STATUS
EFIAPI
UefiMain (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  volatile UINT32  *Header = (volatile UINT32 *)(UINTN)RING_BASE;
  volatile UINT8   *Data   = (volatile UINT8 *)(UINTN)(RING_BASE + RING_HEADER);
  UINT32  Sig;
  UINT32  Start;
  UINT32  Size;
  UINT32  Valid;
  UINT32  Begin;
  UINT32  Position;
  UINT32  Index;
  UINT32  Absolute;
  UINT32  Length;
  UINT32  Shown;
  UINT8   Byte;

  // Volatile ring reads are copied into plain locals before formatting.
  Sig   = Header[0];
  Start = Header[1];
  Size  = Header[2];

  Print (L"== UMI BOOT LOG ==\r\n");
  Print (L"sig=%x start=%x size=%x cap=%x\r\n", Sig, Start, Size, (UINT32)RING_CAPACITY);
  if (Sig != RING_SIGNATURE) {
    Print (L"ramoops header invalid; nothing to show\r\n");
    WaitKey (60000000);
    return EFI_SUCCESS;
  }

  Valid = (Size < RING_CAPACITY) ? Size : RING_CAPACITY;
  if (Valid == 0) {
    Print (L"ring empty\r\n");
    WaitKey (30000000);
    return EFI_SUCCESS;
  }

  Begin    = (Start >= Valid) ? (Start - Valid) : (Start + RING_CAPACITY - Valid);
  Position = 0;
  Length   = 0;
  mLine[0] = 0;
  while (Position < Valid) {
    Absolute = (Begin + Position) % RING_CAPACITY;
    Byte     = (UINT8)Data[Absolute];
    Position++;
    if (Byte == '\n') {
      mLine[Length] = 0;
      if (Length > 0) {
        Remember (mTailText, &mTailCount, &mTailHead, MAX_TAIL);
        if (LineMatches ()) {
          Remember (mMatchText, &mMatchCount, &mMatchHead, MAX_MATCH);
        }
      }

      Length   = 0;
      mLine[0] = 0;
      continue;
    }

    if (Length < MAX_LINE) {
      if ((Byte < 0x20) || (Byte > 0x7E)) {
        Byte = ' ';
      }

      mLine[Length++] = (CHAR8)Byte;
    }
  }

  mLine[Length] = 0;
  if (Length > 0) {
    Remember (mTailText, &mTailCount, &mTailHead, MAX_TAIL);
    if (LineMatches ()) {
      Remember (mMatchText, &mMatchCount, &mMatchHead, MAX_MATCH);
    }
  }

  Print (L"valid=%x lines: match=%u tail=%u\r\n", Valid, mMatchCount, mTailCount);
  Print (L"---- markers ----\r\n");
  Shown = (mMatchCount > MATCH_SHOW) ? MATCH_SHOW : mMatchCount;
  for (Index = mMatchCount - Shown; Index < mMatchCount; Index++) {
    Print (L"%a\r\n", mMatchText[(mMatchCount < MAX_MATCH) ? Index : ((mMatchHead + Index) % MAX_MATCH)]);
  }

  if (mMatchCount == 0) {
    Print (L"(no marker in this ring)\r\n");
  }

  Print (L"---- newest %u ----\r\n", TAIL_SHOW);
  Shown = (mTailCount > TAIL_SHOW) ? TAIL_SHOW : mTailCount;
  for (Index = mTailCount - Shown; Index < mTailCount; Index++) {
    Print (L"%a\r\n", mTailText[(mTailCount < MAX_TAIL) ? Index : ((mTailHead + Index) % MAX_TAIL)]);
  }

  Print (L"press any key to return\r\n");
  WaitKey (90000000);
  return EFI_SUCCESS;
}
