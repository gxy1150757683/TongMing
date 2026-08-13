@echo off
setlocal enabledelayedexpansion
chcp 936 >nul

rem ============================================================
rem  TongMing.bat - 在线自更新批处理脚本
rem
rem  【流程简介】
rem  1. 配置区    ：集中定义本地版本号、远程版本号地址、脚本下载地址
rem  2. 跳过检测  ：3 秒倒计时，按任意键可立即跳过更新检测，直接进入业务区
rem  3. 版本检测  ：下载远程版本号（连接与总耗时均限 3 秒，超时即放弃）；
rem                 用 PowerShell [version] 按段比较版本号大小
rem  4. 自动更新  ：发现新版本后直接自动下载并替换（不再询问）；
rem                 下载成功后生成"延迟替身"脚本并退出自身，
rem                 替身等 3 秒（原脚本已退出释放文件占用）后
rem                 覆盖原脚本、重启新版、最后删除自己
rem  5. 业务区    ：无论更新成功与否，最终都会进入 :BUSINESS 标签
rem                 执行用户自己的业务代码
rem
rem  【容错策略】
rem  - 网络超时 / 下载失败 / 文件为空 / 拿到 404 页面
rem    → 一律降级为"使用当前版本继续运行"，不中断主业务流程
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
rem  第1步：3 秒等待窗口，按任意键跳过更新检测，不按键则 3 秒后自动检测
rem  choice 命令只能认指定按键，无法监听"任意键"，
rem  所以借助 PowerShell 的 [Console]::KeyAvailable 实现：
rem     - 3 秒内按任意键 -> 退出码 1 -> 跳过检测，直接进业务区
rem     - 倒计时结束无按键 -> 退出码 0 -> 自动开始检测
rem ------------------------------------------------------------
powershell -NoProfile -Command "$d=(Get-Date).AddSeconds(3); Write-Host '3 秒后自动检查更新，按任意键立即跳过...' -NoNewline; while(-not [Console]::KeyAvailable -and (Get-Date) -lt $d){Start-Sleep -Milliseconds 100}; if([Console]::KeyAvailable){Write-Host ' (已跳过)'; exit 1}else{Write-Host ''; exit 0}"
if errorlevel 1 goto :BUSINESS

echo 正在检查更新（任一网络步骤超过 3 秒即放弃）...
echo.

rem ------------------------------------------------------------
rem  第2步：下载远程版本号（连接与总耗时均限 3 秒）
rem ------------------------------------------------------------
curl -s --connect-timeout 3 --max-time 3 -o "%TEMP%\TongMing_ver.txt" "%VER_URL%"
if errorlevel 1 goto :UPDATE_FAILED
if not exist "%TEMP%\TongMing_ver.txt" goto :UPDATE_FAILED

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
rem  [version] 能正确解析 x.y.z 格式并逐段比较大小，
rem  try/catch 兜底：远程版本号格式非法时按"无需更新"处理
rem ------------------------------------------------------------
set "NEED_UPDATE=0"
for /f %%i in (`powershell -NoProfile -Command "try{if([version]'%REMOTE_VER%' -gt [version]'%LOCAL_VER%'){'1'}else{'0'}}catch{'0'}"`) do set "NEED_UPDATE=%%i"

if "%NEED_UPDATE%"=="0" (
    echo 已是最新版本，无需更新。
    echo.
    goto :BUSINESS
)

rem ------------------------------------------------------------
rem  第5步：自动下载新版本（发现新版本直接更新，不再询问）
rem ------------------------------------------------------------
echo ========================================
echo   发现新版本：v%LOCAL_VER% -^> v%REMOTE_VER%
echo   正在自动下载更新...
echo ========================================
curl -s --connect-timeout 3 --max-time 3 -o "%NEW_FILE%" "%SCRIPT_URL%"
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
echo [！] 检查更新超时或网络不可用，已放弃检测，使用当前版本继续运行。
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
