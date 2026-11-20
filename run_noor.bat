@echo off
rem =====================================================================
rem  NOOR - Procedural Islamic Geometry & Heritage Architecture
rem  Double-click this file to play.
rem
rem  You can also pass Godot arguments through it, for example:
rem      run_noor.bat --headless --quit-after 600 -- --selftest
rem      run_noor.bat -- --screen=lab
rem =====================================================================
setlocal
set "HERE=%~dp0"
if "%HERE:~-1%"=="\" set "HERE=%HERE:~0,-1%"

rem 1) Godot installed with winget on this machine
set "GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT%" goto :found

rem 2) manual Godot download location used on this machine
set "GODOT=%USERPROFILE%\Downloads\godat\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT%" goto :found

rem 3) Godot available on PATH
for %%G in (godot.exe) do if not "%%~$PATH:G"=="" set "GODOT=%%~$PATH:G"
if exist "%GODOT%" goto :found

echo.
echo   Godot 4.x was not found on this computer.
echo.
echo   Either install Godot 4 from https://godotengine.org/download
echo   or open this file in a text editor and set the GODOT variable
echo   to the full path of your Godot executable.
echo.
pause
exit /b 1

:found
if "%~1"=="" (
    echo Launching NOOR with:
    echo   %GODOT%
    start "" "%GODOT%" --path "%HERE%"
    exit /b 0
)

rem Arguments were given: run attached so console output and the exit
rem code stay visible (useful for --selftest and other dev flags).
for %%F in ("%GODOT%") do set "GODOT_CONSOLE=%%~dpnF_console%%~xF"
if not exist "%GODOT_CONSOLE%" set "GODOT_CONSOLE=%GODOT%"
"%GODOT_CONSOLE%" --path "%HERE%" %*
exit /b %ERRORLEVEL%
