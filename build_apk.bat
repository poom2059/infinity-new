@echo off
setlocal
cd /d "%~dp0"

rem ใช้ JDK ที่ Gradle ต้องการ (sdkmanager / AGP) — ลอง Temurin 17 ก่อน
if not defined JAVA_HOME (
  if exist "C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot\bin\java.exe" (
    set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.19.10-hotspot"
  ) else if exist "C:\Program Files\Eclipse Adoptium\jdk-21.0.11.10-hotspot\bin\java.exe" (
    set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-21.0.11.10-hotspot"
  )
)
if defined JAVA_HOME set "PATH=%JAVA_HOME%\bin;%PATH%"

rem หา Android SDK ถ้ายังไม่ได้ตั้ง ANDROID_HOME (ตำแหน่งมาตรฐานของ Android Studio บน Windows)
if not defined ANDROID_HOME (
  if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
    set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"
  )
)
if not defined ANDROID_SDK_ROOT if defined ANDROID_HOME set "ANDROID_SDK_ROOT=%ANDROID_HOME%"

if not defined ANDROID_HOME (
  echo.
  echo [ข้อผิดพลาด] ไม่พบ Android SDK
  echo ติดตั้ง Android Studio แล้วเปิด SDK Manager หรือตั้งค่า:
  echo   setx ANDROID_HOME "%%LOCALAPPDATA%%\Android\Sdk"
  echo จากนั้นเปิด CMD/PowerShell ใหม่ แล้วรัน build_apk.bat อีกครั้ง
  echo.
  pause
  exit /b 1
)

set "FLUTTER_CMD=flutter"
where flutter >nul 2>&1
if errorlevel 1 (
  if exist "%USERPROFILE%\flutter\bin\flutter.bat" (
    set "FLUTTER_CMD=%USERPROFILE%\flutter\bin\flutter.bat"
  ) else (
    echo ไม่พบ flutter ใน PATH และไม่พบ %%USERPROFILE%%\flutter\bin\flutter.bat
    pause
    exit /b 1
  )
)

echo JAVA_HOME=%JAVA_HOME%
echo ANDROID_HOME=%ANDROID_HOME%
echo.
echo กำลังสร้าง APK ^(release — ลงชื่อด้วย debug keystore ตาม build.gradle; เหมาะทดสอบ/ใช้เอง^)...
call "%FLUTTER_CMD%" build apk --release
if errorlevel 1 (
  echo.
  echo build ล้มเหลว — ลองรัน: flutter doctor -v
  pause
  exit /b 1
)

echo.
echo สำเร็จ — ไฟล์ติดตั้งอยู่ที่:
echo   %CD%\build\app\outputs\flutter-apk\app-release.apk
echo คัดลอกไฟล์นี้ไปโทรศัพท์ แล้วเปิดติดตั้ง ^(อนุญาตติดตั้งจากแหล่งที่ไม่รู้จักถ้าระบบถาม^)
echo.
pause
endlocal
