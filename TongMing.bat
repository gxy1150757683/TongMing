@echo off
setlocal enabledelayedexpansion
chcp 936 >nul

rem ============================================================
rem  TongMing.bat - 在线自更新批处理脚本
rem
rem  【流程简介】
rem  1. 配置区       ：集中定义本地版本号、远程版本号地址、脚本下载地址
rem  2. 自动检测更新 ：打开脚本【立即】在后台下载远程版本号，同时监听键盘：
rem                    - 任一网络步骤超过 3 秒 → 自动放弃检测
rem                    - 用户按任意键 → 立即跳过检测
rem                    两种情况均直接降级进入业务区，不阻塞用户使用
rem  3. 版本比较     ：用 PowerShell [version] 按段比较版本号大小
rem  4. 自动下载更新 ：发现新版本后【立即】后台下载新脚本，
rem                    同样受"3 秒超时 + 任意键跳过"保护
rem                    （网络慢或急用时随时可中断更新，继续用当前版本）
rem  5. 自我替换     ：下载成功后生成"延迟替身"并退出自身，替身
rem                    等 3 秒覆盖原脚本、重启新版、最后删除自己
rem  6. 业务区       ：无论更新是否完成，最终都会进入 :BUSINESS
rem
rem  【容错策略】
rem  - 网络超时 / 按键跳过 / 下载失败 / 文件为空 / 404 页面
rem    → 一律降级为"使用当前版本继续运行"，绝不中断主业务流程
rem
rem  【版本号比较说明】
rem  不能直接用 if "%A%"=="%B%" 做字符串比较，原因：
rem    "1.9.9" 与 "1.10.0" 逐字符比较时，第 2 段 "9" > "1"，
rem    会错误地认为 1.9.9 比 1.10.0 新。
rem  常用解决办法（大家通常的做法）：
rem    1) 补零法：每段补足固定位数再比较
rem       （1.9.9 -> 000100090009，1.10.0 -> 000100100000）
rem    2) 逐段拆分法：for /f 按 "." 拆开后，从高位到低位逐段比较
rem    3) 专用解析器：本脚本采用 PowerShell 的 [version] 类型，
rem       它能正确解析 x.y.z 格式并逐段比较，最省事、最可靠
rem ============================================================
set "LOCAL_VER=1.0.0"
set "VER_URL=https://raw.githubusercontent.com/gxy1150757683/TongMing/refs/heads/main/version.txt"
set "SCRIPT_URL=https://raw.githubusercontent.com/gxy1150757683/TongMing/refs/heads/main/TongMing.bat"
set "NEW_FILE=%TEMP%\TongMing_new.bat"

cls
echo ========================================
echo   TongMing 在线更新脚本
echo ========================================
echo 当前脚本版本：%LOCAL_VER%
echo.

rem ------------------------------------------------------------
rem  第1步：立即开始自动检测更新
rem  核心：打开脚本【马上】后台下载远程版本号，不等待用户；
rem  同时监听键盘——按任意键立即跳过；超过 3 秒自动放弃。
rem  具体逻辑在下方通用函数 :DO_DOWNLOAD_OR_SKIP 中
rem ------------------------------------------------------------
echo 正在检查更新，按任意键可立即跳过（超过 3 秒自动放弃）...
set "DL_URL=%VER_URL%"
set "DL_FILE=%TEMP%\TongMing_ver.txt"
call :DO_DOWNLOAD_OR_SKIP
if "!DL_RESULT!"=="1" (
    echo [已跳过更新检测，直接进入业务区]
    goto :BUSINESS
)
if not "!DL_RESULT!"=="0" (
    echo [更新检测超时或网络不可用，已放弃检测]
    goto :UPDATE_FAILED
)

rem ------------------------------------------------------------
rem  第2步：兜底校验下载文件（存在且非空）
rem ------------------------------------------------------------
if not exist "%TEMP%\TongMing_ver.txt" goto :UPDATE_FAILED
for %%A in ("%TEMP%\TongMing_ver.txt") do if %%~zA EQU 0 goto :UPDATE_FAILED

rem ------------------------------------------------------------
rem  第3步：读取远程版本号（去掉空白和换行）
rem ------------------------------------------------------------
set "REMOTE_VER="
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-Content -LiteralPath '%TEMP%\TongMing_ver.txt' -Raw).Trim()"`) do set "REMOTE_VER=%%i"
if not defined REMOTE_VER goto :UPDATE_FAILED

echo 远程最新版本：%REMOTE_VER%
echo.

rem ------------------------------------------------------------
rem  第4步：用 PowerShell [version] 按段比较版本号
rem ------------------------------------------------------------
set "NEED_UPDATE=0"
for /f %%i in (`powershell -NoProfile -Command "try{if([version]'%REMOTE_VER%' -gt [version]'%LOCAL_VER%'){'1'}else{'0'}}catch{'0'}"`) do set "NEED_UPDATE=%%i"

if "!NEED_UPDATE!"=="0" (
    echo 已是最新版本，无需更新。
    echo.
    goto :BUSINESS
)

rem ------------------------------------------------------------
rem  第5步：发现新版本 → 立即自动下载新脚本
rem  同样受"3 秒超时 + 任意键跳过"保护，网络慢或急用时
rem  可随时中断更新，继续用当前版本运行
rem ------------------------------------------------------------
echo ========================================
echo   发现新版本：v%LOCAL_VER% -^> v%REMOTE_VER%
echo ========================================
echo 正在自动下载新版本，按任意键可跳过更新（超过 3 秒自动放弃）...
set "DL_URL=%SCRIPT_URL%"
set "DL_FILE=%NEW_FILE%"
call :DO_DOWNLOAD_OR_SKIP
if "!DL_RESULT!"=="1" (
    echo [已跳过更新，继续使用当前版本运行]
    goto :BUSINESS
)
if not "!DL_RESULT!"=="0" (
    echo [新版本下载超时或失败]
    goto :DOWNLOAD_FAILED
)

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
echo.
echo [！] 更新检测超时、被跳过或网络不可用，使用当前版本继续运行。
echo.
goto :BUSINESS

:DOWNLOAD_FAILED
echo.
echo [！] 新版本下载超时、被跳过或失败，先使用当前版本继续运行。
echo.
goto :BUSINESS

rem ============================================================
rem  通用函数：后台下载 + 任意键跳过 + 3 秒超时
rem  入参（调用前设置）：
rem    DL_URL  = 下载地址
rem    DL_FILE = 输出文件路径
rem  返回：
rem    DL_RESULT = 0 下载成功
rem              1 用户按任意键跳过
rem              2 超过 3 秒 / curl 失败
rem
rem  原理：用户要求"打开即自动更新，但超过 3 秒或按任意键就跳过"。
rem  但 BAT 的 curl 是阻塞式的，等它结束就无法同时监听按键，
rem  所以用 PowerShell 生成一个独立 Process 异步启动 curl
rem  （无窗口、不阻塞），同时主线程每 100ms 轮询一次：
rem    - [Console]::KeyAvailable 检测任意键（不管按的是哪个键）
rem    - (Get-Date) 检测 3 秒超时
rem    - $p.HasExited 检测 curl 是否提前完成（完成则立即放行，
rem      不必干等满 3 秒，网好时几乎无感）
rem ============================================================
:DO_DOWNLOAD_OR_SKIP
if exist "%TEMP%\TongMing_dl.ps1" del "%TEMP%\TongMing_dl.ps1" >nul 2>&1
echo $p = New-Object System.Diagnostics.Process >> "%TEMP%\TongMing_dl.ps1"
echo $p.StartInfo.FileName = 'curl.exe' >> "%TEMP%\TongMing_dl.ps1"
echo $p.StartInfo.Arguments = '-s --connect-timeout 3 --max-time 3 -o "%DL_FILE%" "%DL_URL%"' >> "%TEMP%\TongMing_dl.ps1"
echo $p.StartInfo.UseShellExecute = $false >> "%TEMP%\TongMing_dl.ps1"
echo $p.StartInfo.CreateNoWindow = $true >> "%TEMP%\TongMing_dl.ps1"
echo $p.Start() ^| Out-Null >> "%TEMP%\TongMing_dl.ps1"
echo $e = (Get-Date).AddSeconds(3) >> "%TEMP%\TongMing_dl.ps1"
echo while (-not $p.HasExited -and (Get-Date) -lt $e -and -not [Console]::KeyAvailable) { Start-Sleep -Milliseconds 100 } >> "%TEMP%\TongMing_dl.ps1"
echo if ([Console]::KeyAvailable) { >> "%TEMP%\TongMing_dl.ps1"
echo     if (-not $p.HasExited) { $p.Kill() } >> "%TEMP%\TongMing_dl.ps1"
echo     exit 1 >> "%TEMP%\TongMing_dl.ps1"
echo } >> "%TEMP%\TongMing_dl.ps1"
echo if (-not $p.HasExited) { >> "%TEMP%\TongMing_dl.ps1"
echo     $p.Kill() >> "%TEMP%\TongMing_dl.ps1"
echo     exit 2 >> "%TEMP%\TongMing_dl.ps1"
echo } >> "%TEMP%\TongMing_dl.ps1"
echo if ($p.ExitCode -eq 0) { >> "%TEMP%\TongMing_dl.ps1"
echo     exit 0 >> "%TEMP%\TongMing_dl.ps1"
echo } >> "%TEMP%\TongMing_dl.ps1"
echo exit 2 >> "%TEMP%\TongMing_dl.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\TongMing_dl.ps1"
set "DL_RESULT=!errorlevel!"
del "%TEMP%\TongMing_dl.ps1" >nul 2>&1
exit /b

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
