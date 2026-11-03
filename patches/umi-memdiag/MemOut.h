// SPDX-License-Identifier: BSD-2-Clause-Patent
// Mirror every DEBUG line onto the EFI console. The umi port has no accessible
// UART and no USB log sink, so the screen is the only way to read this app.
#ifndef UMI_MEM_OUT_H
#define UMI_MEM_OUT_H

#include <Base.h>
#include <Library/DebugLib.h>
#include <Library/PrintLib.h>
#include <Library/UefiLib.h>

STATIC
VOID
EFIAPI
UmiEmit (IN UINTN ErrorLevel, IN CONST CHAR8 *Format, ...)
{
  VA_LIST  Marker;
  CHAR8    Line[256];
  UINTN    Length;

  VA_START (Marker, Format);
  AsciiVSPrint (Line, sizeof (Line), Format, Marker);
  VA_END (Marker);

  Length = AsciiStrLen (Line);
  if ((Length > 0) && (Line[Length - 1] == '\n')) {
    Line[Length - 1] = '\0';
    Length--;
  }

  AsciiPrint ("%a\r\n", Line);
  DebugPrint (ErrorLevel, "%a\n", Line);
}

#undef DEBUG
#define DEBUG(Buffer)  UmiEmit Buffer

#endif
