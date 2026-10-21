@echo off
setlocal EnableDelayedExpansion
rem ==================================================================
rem  Star Dragon Voyager launcher
rem    sdv            play the game
rem    sdv edit       open the project in the Godot editor
rem    sdv touch      play with phone touch controls (mouse = finger)
rem    sdv test       automated smoke test (all abilities), prints PASS/FAIL
rem    sdv shot       save a screenshot to build\screenshot.png
rem    sdv build      export the Windows game to build\windows\
rem    sdv sprites    export generated sprite sheets to assets\generated\
rem    sdv wave 3     play, starting at wave 3 (for testing later enemies)
rem    sdv import     convert AI-made sprite sheets (tools\sprite_import.json) into game sheets
rem  Godot is found via the GODOT environment variable, else "godot" on PATH.
rem ==================================================================
cd /d "%~dp0"

set "GODOT_BIN=%GODOT%"
if not defined GODOT_BIN (
    where godot >nul 2>nul && set "GODOT_BIN=godot"
)
if not defined GODOT_BIN (
    echo Could not find Godot. Point the GODOT variable at your Godot .exe, for example:
    echo     setx GODOT "C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe"
    exit /b 1
)

set "CMD=%~1"
if "%CMD%"=="" set "CMD=play"

if /i "%CMD%"=="play"    goto play
if /i "%CMD%"=="edit"    goto edit
if /i "%CMD%"=="touch"   goto touch
if /i "%CMD%"=="test"    goto test
if /i "%CMD%"=="shot"    goto shot
if /i "%CMD%"=="build"   goto build
if /i "%CMD%"=="sprites" goto sprites
if /i "%CMD%"=="wave"    goto wave
if /i "%CMD%"=="import"  goto import
goto help

:import
rem Converts AI-made sprite sheets listed in tools\sprite_import.json into game sheets.
python tools\import_sprites.py %2
if errorlevel 1 exit /b 1
call "%GODOT_BIN%" --headless --path . --import >nul 2>&1
echo Done. Press F5 to see the new sprites in game.
exit /b 0

:wave
call "%GODOT_BIN%" --path . -- --wave=%2
exit /b %errorlevel%

:play
call "%GODOT_BIN%" --path . %2 %3 %4
exit /b %errorlevel%

:edit
start "" "%GODOT_BIN%" --path . -e
exit /b 0

:touch
call "%GODOT_BIN%" --path . -- --touch
exit /b %errorlevel%

:test
echo Running smoke test (about 15 seconds)...
set "LOG=%TEMP%\sdv_test.log"
call "%GODOT_BIN%" --headless --path . --quit-after 900 -- --demo > "%LOG%" 2>&1
findstr /c:"ERROR" "%LOG%" >nul
if !errorlevel! equ 0 (
    echo FAIL - errors found:
    findstr /c:"ERROR" /c:"at:" "%LOG%"
    exit /b 1
)
echo PASS - no errors.
exit /b 0

:shot
if not exist build mkdir build
call "%GODOT_BIN%" --path . --resolution 1280x720 -- --screenshot=%CD%\build\screenshot.png --demo
echo Saved build\screenshot.png
exit /b 0

:build
for /f "tokens=1-4 delims=." %%a in ('call "%GODOT_BIN%" --version') do set "GVER=%%a.%%b.%%c.%%d"
if not exist "%APPDATA%\Godot\export_templates\!GVER!" (
    echo Export templates for Godot !GVER! are not installed.
    echo In the editor: Editor ^> Manage Export Templates ^> Download and Install. Then run "sdv build" again.
    exit /b 1
)
if not exist build\windows mkdir build\windows
call "%GODOT_BIN%" --headless --path . --export-release "Windows Desktop" build\windows\StarDragonVoyager.exe
if exist build\windows\StarDragonVoyager.exe (
    echo Built build\windows\StarDragonVoyager.exe
    exit /b 0
)
echo Build failed - see the messages above.
exit /b 1

:sprites
call "%GODOT_BIN%" --headless --path . -- --export-sprites
echo Sprite sheets written to assets\generated\
exit /b 0

:help
echo Usage: sdv [play^|edit^|touch^|test^|shot^|build^|sprites^|wave N^|import]
exit /b 1
