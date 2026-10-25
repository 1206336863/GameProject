@echo off
setlocal
set "NEON_ENGINE=%~dp0..\tools\godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%NEON_ENGINE%" powershell -NoProfile -File "%~dp0scripts\setup_engine.ps1"
if not exist "%NEON_ENGINE%" goto missing
"%NEON_ENGINE%" --headless --editor --path "%~dp0." --import
if errorlevel 1 goto missing
start "" "%NEON_ENGINE%" --path "%~dp0." --rendering-method gl_compatibility
exit /b
:missing
echo Engine setup or asset import failed. See README.md.
pause
