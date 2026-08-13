@echo off
setlocal enabledelayedexpansion
chcp 936 >nul

rem ============================================================
rem  配置区：每次发新版只改这里第一行版本号
rem ============================================================
set "LOCAL_VER=1.0.0"
set "VER_URL=https://raw.githubusercontent.com/gxy1150757683/TongMing/refs/heads/main/version.txt"
set "SCRIPT_URL=https://raw.githubusercontent.com/gxy1150757683/TongMing/refs/heads/main/TongMing.bat"
set "NEW_FILE=%TEMP%\TongMing_new.bat"

cls
echo 当前脚本版本：%LOCAL_VER%
echo 正在检查更新...
echo.

rem ------------------------------------------------------------
rem  第1步：下载远程版本号
rem ------------------------------------------------------------
curl -s --connect-timeout 8 --max-time 15 -o "%TEMP%\TongMing_ver.txt" "%VER_URL%"
if errorlevel 1 goto :UPDATE_FAILED
if not exist "%TEMP%\TongMing_ver.txt" goto :UPDATE_FAILED

rem ------------------------------------------------------------
rem  第2步：读取远程版本号（去掉空白和换行）
rem ------------------------------------------------------------
set "REMOTE_VER="
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-Content -LiteralPath '%TEMP%\TongMing_ver.txt' -Raw).Trim()"`) do set "REMOTE_VER=%%i"
if not defined REMOTE_VER goto :UPDATE_FAILED

echo 远程最新版本：%REMOTE_VER%
echo.

rem ------------------------------------------------------------
rem  第3步：版本对比
rem ------------------------------------------------------------
if "%LOCAL_VER%"=="%REMOTE_VER%" (
    echo 已是最新版本，无需更新。
    echo.
    goto :BUSINESS
)

rem ------------------------------------------------------------
rem  第4步：询问用户是否更新
rem ------------------------------------------------------------
echo ========================================
echo   发现新版本：v%LOCAL_VER% -^> v%REMOTE_VER%
echo ========================================
echo.
choice /c YN /m "按 Y 立即更新，按 N 跳过更新"
if errorlevel 2 goto :BUSINESS

rem ------------------------------------------------------------
rem  第5步：下载新版本脚本
rem ------------------------------------------------------------
echo.
echo 正在下载新版本，请稍候...
curl -s --connect-timeout 8 --max-time 15 -o "%NEW_FILE%" "%SCRIPT_URL%"
if errorlevel 1 goto :DOWNLOAD_FAILED
if not exist "%NEW_FILE%" goto :DOWNLOAD_FAILED
for %%A in ("%NEW_FILE%") do if %%~zA EQU 0 goto :DOWNLOAD_FAILED

rem 防止下载到 GitHub 的 404 错误页面
findstr /m "404" "%NEW_FILE%" >nul 2>&1 && goto :DOWNLOAD_FAILED

rem ------------------------------------------------------------
rem  第6步：生成"延迟替身"并让自己退出
rem  说明：bat 运行中不能覆盖自己，所以先启动一个独立窗口
rem       等 3 秒，本脚本退出释放文件占用后，替身再覆盖重启
rem ------------------------------------------------------------
(
echo @echo off
echo chcp 936 ^>nul
echo timeout /t 3 /nobreak ^>nul
echo copy /y "%NEW_FILE%" "%~f0" ^>nul
echo start "" "%~f0"
echo del "%%~f0"
) > "%TEMP%\TongMing_updater.bat"

echo.
echo 更新完成，3 秒后自动启动新版本...
start "" "%TEMP%\TongMing_updater.bat"
exit /b

:UPDATE_FAILED
echo [！] 暂时无法连接更新服务器，将使用当前版本继续运行。
echo.
goto :BUSINESS

:DOWNLOAD_FAILED
echo [！] 新版本下载失败，请检查网络后重试。先使用当前版本继续运行。
echo.
goto :BUSINESS

rem ============================================================
rem  业务区：从下面开始填写你自己的业务功能代码
rem ============================================================
:BUSINESS
echo ========================================
echo   你的业务功能写在这里
echo ========================================
echo.
rem 下方 pause 仅为调试用，正式使用时可删除
pause
exit /b
