@echo off
setlocal
rem Prefer the folder this script lives in when it is inside the Flutter project.
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

if exist "%SCRIPT_DIR%\pubspec.yaml" (
  cd /d "%SCRIPT_DIR%"
  goto run_flutter
)

rem One level up (e.g. script in a subfolder of the repo).
if exist "%SCRIPT_DIR%\..\pubspec.yaml" (
  cd /d "%SCRIPT_DIR%\.."
  goto run_flutter
)

rem Known locations on this machine (edit if you moved the repo).
set "FALLBACK1=c:\Users\Admin\Desktop\infinity-new-main"
set "FALLBACK2=c:\Users\Admin\Desktop\infinity-new-main\infinity-new-main"
if exist "%FALLBACK1%\pubspec.yaml" (
  cd /d "%FALLBACK1%"
  goto run_flutter
)
if exist "%FALLBACK2%\pubspec.yaml" (
  cd /d "%FALLBACK2%"
  goto run_flutter
)

echo ERROR: pubspec.yaml not found next to this script, one level up, or at:
echo   %FALLBACK1%
echo   %FALLBACK2%
echo Put this .bat inside the Flutter project root ^(folder that contains pubspec.yaml^), or edit FALLBACK paths.
pause
exit /b 1

:run_flutter
echo Running Flutter web (Chrome) from: %CD%

set "FLUTTER_CMD="
if defined FLUTTER_ROOT if exist "%FLUTTER_ROOT%\bin\flutter.bat" set "FLUTTER_CMD=%FLUTTER_ROOT%\bin\flutter.bat"
if not defined FLUTTER_CMD if exist "%LOCALAPPDATA%\flutter\bin\flutter.bat" set "FLUTTER_CMD=%LOCALAPPDATA%\flutter\bin\flutter.bat"
if not defined FLUTTER_CMD if exist "%USERPROFILE%\flutter\bin\flutter.bat" set "FLUTTER_CMD=%USERPROFILE%\flutter\bin\flutter.bat"
if not defined FLUTTER_CMD if exist "C:\flutter\bin\flutter.bat" set "FLUTTER_CMD=C:\flutter\bin\flutter.bat"
if not defined FLUTTER_CMD if exist "C:\src\flutter\bin\flutter.bat" set "FLUTTER_CMD=C:\src\flutter\bin\flutter.bat"
if not defined FLUTTER_CMD if exist "D:\flutter\bin\flutter.bat" set "FLUTTER_CMD=D:\flutter\bin\flutter.bat"
if not defined FLUTTER_CMD where flutter >nul 2>&1 && set "FLUTTER_CMD=flutter"

if not defined FLUTTER_CMD (
  echo ERROR: Could not find flutter.bat.
  echo Set FLUTTER_ROOT to your SDK folder ^(the one that contains bin\flutter.bat^), or add Flutter\bin to PATH.
  pause
  exit /b 1
)

echo Using Flutter: %FLUTTER_CMD%
call "%FLUTTER_CMD%" run -d chrome
if errorlevel 1 pause
endlocal
