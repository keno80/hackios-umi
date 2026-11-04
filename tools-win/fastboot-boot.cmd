@echo off
rem umi one-key on-device launcher (ASCII only)
setlocal
set "STARTCD=%CD%"
set "PS=%~dp0fastboot-boot.ps1"
where powershell >nul 2>nul
if errorlevel 1 (
  echo [X] powershell not found on PATH
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS%" -ImageDir "%STARTCD%"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" pause
endlocal
exit /b %RC%
