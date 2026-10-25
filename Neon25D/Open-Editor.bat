@echo off
setlocal
set "NEON_ENGINE=%~dp0..\tools\godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%NEON_ENGINE%" powershell -NoProfile -File "%~dp0scripts\setup_engine.ps1"
if not exist "%NEON_ENGINE%" goto missing
start "" "%NEON_ENGINE%" --editor --path "%~dp0."
exit /b
:missing
echo Engine missing. See README.md.
pause
