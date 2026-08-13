@echo off
setlocal enabledelayedexpansion
chcp 936 >nul

rem ============================================================
rem  TongMing.bat - 在线自更新批处理脚本
rem
rem  【流程简介】
rem  1. 配置区       ：集中定义本地版本号、远程版本号地址、脚本下载地址
rem  2. 自动检测更新 ：打开脚本【立即】在后台下载远程版本号，同时
rem                    显示 5 秒倒计时并监听键盘（三者同步进行）：
rem                    - 下载一旦完成 → 立即结束倒计时，继续后续流程
rem                    - 5 秒倒计时结束还未下载完 → 自动放弃检测
rem                    - 用户按任意键 → 立即跳过检测
rem  3. 版本比较     ：用 PowerShell [version] 按段比较版本号大小
rem  4. 自动下载更新 ：发现新版本后【立即】后台下载新脚本，同样有
rem                    5 秒倒计时 + 任意键跳过保护
rem  5. 自我替换     ：下载成功后生成"延迟替身"并退出自身，替身
rem                    等 3 秒覆盖原脚本、重启新版、最后删除自己
rem  6. 业务区       ：无论更新是否完成，最终都会进入 :BUSINESS
rem
rem  【显示说明】——同一个"当前版本"行按时间顺序平滑演变
rem    时刻1 刚打开     ：  当前版本：1.0.0
rem    时刻2 检测中     ：  当前版本：1.0.0 --- 更新ing...5s (任意键跳过)
rem    时刻3a 无更新    ：  当前版本：1.0.0      已云端最新！
rem    时刻3b 有更新完成：  当前版本：1.0.0      (已更新)远程版本:1.0.1
rem    时刻3c 跳过/失败 ：  当前版本：1.0.0      (已跳过更新检测) 等
rem  （过程渲染与倒计时在 PowerShell 进程内用 \r 原位覆盖完成，
rem    结果渲染由 BAT 用 cls 重绘最终界面，两者画面无缝衔接）
rem
rem  【按键检测说明】——为什么用 GetAsyncKeyState
rem  [Console]::KeyAvailable 强依赖控制台输入句柄，在 VS Code 集成
rem  终端、部分终端模拟器、标准输入被重定向时会直接抛异常导致整个
rem  检测流程失败。改用 user32.dll 的 GetAsyncKeyState 轮询键盘
rem  状态（系统级 API），无论在任何环境下都稳定可靠。
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

rem ------------------------------------------------------------
rem  初始画面：时刻1 —— 标题 + 当前版本
rem ------------------------------------------------------------
cls
echo ========================================
echo   TongMing 在线更新脚本
echo ========================================
echo.
echo   当前版本：%LOCAL_VER%
echo.

rem ------------------------------------------------------------
rem  第1步：立即自动检测更新（时刻2：状态行演变为倒计时动画）
rem ------------------------------------------------------------
set "DL_URL=%VER_URL%"
set "DL_FILE=%TEMP%\TongMing_ver.txt"
set "DL_MSG=更新ing"
call :DO_DOWNLOAD_OR_SKIP
if "!DL_RESULT!"=="1" (
    call :SCREEN "      (已跳过更新检测)"
    goto :BUSINESS
)
if not "!DL_RESULT!"=="0" (
    call :SCREEN "      (更新检测失败，使用当前版本)"
    goto :BUSINESS
)

rem ------------------------------------------------------------
rem  第2步：读取远程版本号（去掉空白和换行）
rem ------------------------------------------------------------
set "REMOTE_VER="
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "(Get-Content -LiteralPath '%TEMP%\TongMing_ver.txt' -Raw).Trim()"`) do set "REMOTE_VER=%%i"
if not defined REMOTE_VER goto :UPDATE_FAILED

rem ------------------------------------------------------------
rem  第3步：用 PowerShell [version] 按段比较版本号
rem  退出码约定：0 = 需要更新（远程版本更高）
rem              1 = 无需更新 / 版本号格式非法
rem ------------------------------------------------------------
powershell -NoProfile -Command "try{if([version]'%REMOTE_VER%' -gt [version]'%LOCAL_VER%'){exit 0}else{exit 1}}catch{exit 1}"
if errorlevel 1 goto :NO_UPDATE

rem ------------------------------------------------------------
rem  第4步：发现新版本 → 立即自动下载新脚本
rem ------------------------------------------------------------
set "DL_URL=%SCRIPT_URL%"
set "DL_FILE=%NEW_FILE%"
set "DL_MSG=更新下载中"
call :DO_DOWNLOAD_OR_SKIP
if "!DL_RESULT!"=="1" (
    call :SCREEN "      (已跳过更新，继续使用当前版本)"
    goto :BUSINESS
)
if not "!DL_RESULT!"=="0" (
    call :SCREEN "      (新版本下载失败，先使用当前版本)"
    goto :BUSINESS
)

rem 防止下载到 GitHub 的 404 错误页面
findstr /m "404" "%NEW_FILE%" >nul 2>&1 && (
    call :SCREEN "      (下载内容异常，先使用当前版本)"
    goto :BUSINESS
)

rem ------------------------------------------------------------
rem  时刻3b：更新下载成功，重绘最终界面
rem ------------------------------------------------------------
call :SCREEN "      (已更新)远程版本:!REMOTE_VER!"

rem ------------------------------------------------------------
rem  第5步：生成"延迟替身"并让自己退出
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

:NO_UPDATE
call :SCREEN "      已云端最新！"
goto :BUSINESS

:UPDATE_FAILED
call :SCREEN "      (更新检测失败，使用当前版本)"
goto :BUSINESS

rem ============================================================
rem  界面渲染子函数：cls 重绘"标题 + 当前版本 + 结果状态"
rem  入参：%~1 = 当前版本行末尾追加的状态文案（以空格开头）
rem  示例：call :SCREEN "      已云端最新！"
rem ============================================================
:SCREEN
cls
echo ========================================
echo   TongMing 在线更新脚本
echo ========================================
echo.
echo   当前版本：%LOCAL_VER%%~1
echo.
exit /b

rem ============================================================
rem  通用函数：后台下载 + 任意键跳过 + 5 秒倒计时（三者同步）
rem  入参（调用前设置）：
rem    DL_URL  = 下载地址
rem    DL_FILE = 输出文件路径
rem    DL_MSG  = 阶段提示词（"更新ing" / "更新下载中"）
rem  返回：
rem    DL_RESULT = 0 下载成功
rem              1 用户按任意键跳过
rem              2 超过 5 秒 / 下载失败 / 环境异常
rem
rem  原理与关键点：
rem  1. BAT 的 curl 是阻塞式的，等它结束就无法同时监听按键，
rem     所以用 PowerShell 生成一个独立 Process 异步启动 curl
rem     （无窗口、不阻塞），主循环每 100ms 轮询一次。
rem  2. 按键检测用 user32.dll 的 GetAsyncKeyState（系统级键盘
rem     状态），不依赖控制台输入句柄，在 VS Code 集成终端、
rem     重定向输入、任何终端模拟器下都不会抛异常。
rem  3. curl 路径动态解析（PATH 找不到则用 System32），加 -L
rem     跟随 GitHub 重定向，所有关键步骤 try/catch 兜底。
rem  4. 下载完成立即退出循环【绝不等满 5 秒】（网好时几乎无感）。
rem  5. 渲染：整个动画画面由本 PowerShell 进程 cls 重画 +
rem     \r 原位刷新（同进程内绝对可靠）；退出后由 BAT 调用
rem     :SCREEN 用 cls 重绘最终结果，两幅画面无缝衔接 1→2→3。
rem ============================================================
:DO_DOWNLOAD_OR_SKIP
if exist "%TEMP%\TongMing_dl.ps1" del "%TEMP%\TongMing_dl.ps1" >nul 2>&1
echo cls >> "%TEMP%\TongMing_dl.ps1"
echo Write-Host '========================================' >> "%TEMP%\TongMing_dl.ps1"
echo Write-Host '  TongMing 在线更新脚本' >> "%TEMP%\TongMing_dl.ps1"
echo Write-Host '========================================' >> "%TEMP%\TongMing_dl.ps1"
echo Write-Host '' >> "%TEMP%\TongMing_dl.ps1"
echo $v='%LOCAL_VER%' >> "%TEMP%\TongMing_dl.ps1"
echo $m='%DL_MSG%' >> "%TEMP%\TongMing_dl.ps1"
echo Add-Type -TypeDefinition @" >> "%TEMP%\TongMing_dl.ps1"
echo using System; >> "%TEMP%\TongMing_dl.ps1"
echo using System.Runtime.InteropServices; >> "%TEMP%\TongMing_dl.ps1"
echo public class K { >> "%TEMP%\TongMing_dl.ps1"
echo     [DllImport("user32.dll")] >> "%TEMP%\TongMing_dl.ps1"
echo     public static extern short GetAsyncKeyState(int vKey); >> "%TEMP%\TongMing_dl.ps1"
echo } >> "%TEMP%\TongMing_dl.ps1"
echo "@ >> "%TEMP%\TongMing_dl.ps1"
echo function Any-Key-Pressed { >> "%TEMP%\TongMing_dl.ps1"
echo     for ($i = 1; $i -le 254; $i++) { >> "%TEMP%\TongMing_dl.ps1"
echo         if ((K::GetAsyncKeyState($i) -band 0x8000) -ne 0) { return $true } >> "%TEMP%\TongMing_dl.ps1"
echo     } >> "%TEMP%\TongMing_dl.ps1"
echo     return $false >> "%TEMP%\TongMing_dl.ps1"
echo } >> "%TEMP%\TongMing_dl.ps1"
echo $curl = (Get-Command curl.exe -ErrorAction SilentlyContinue).Source >> "%TEMP%\TongMing_dl.ps1"
echo if (-not $curl) { $curl = "$env:windir\System32\curl.exe" } >> "%TEMP%\TongMing_dl.ps1"
echo if (-not (Test-Path $curl)) { Write-Host ''; exit 2 } >> "%TEMP%\TongMing_dl.ps1"
echo $p = New-Object System.Diagnostics.Process >> "%TEMP%\TongMing_dl.ps1"
echo $p.StartInfo.FileName = $curl >> "%TEMP%\TongMing_dl.ps1"
echo $p.StartInfo.Arguments = '-s -L --connect-timeout 5 --max-time 5 -o "%DL_FILE%" "%DL_URL%"' >> "%TEMP%\TongMing_dl.ps1"
echo $p.StartInfo.UseShellExecute = $false >> "%TEMP%\TongMing_dl.ps1"
echo $p.StartInfo.CreateNoWindow = $true >> "%TEMP%\TongMing_dl.ps1"
echo try { $p.Start() ^| Out-Null } catch { Write-Host ''; exit 2 } >> "%TEMP%\TongMing_dl.ps1"
echo $pressed = $false >> "%TEMP%\TongMing_dl.ps1"
echo $e = (Get-Date).AddSeconds(5) >> "%TEMP%\TongMing_dl.ps1"
echo $last = -1 >> "%TEMP%\TongMing_dl.ps1"
echo Write-Host ("  当前版本：{0}" -f $v) -NoNewline >> "%TEMP%\TongMing_dl.ps1"
echo while (-not $p.HasExited -and (Get-Date) -lt $e) { >> "%TEMP%\TongMing_dl.ps1"
echo     if ((Any-Key-Pressed)) { $pressed = $true; break } >> "%TEMP%\TongMing_dl.ps1"
echo     $left = [int](($e - (Get-Date)).TotalSeconds) + 1 >> "%TEMP%\TongMing_dl.ps1"
echo     if ($left -ne $last) { >> "%TEMP%\TongMing_dl.ps1"
echo         Write-Host ("`r  当前版本：{0} --- {1}...{2}s (任意键跳过)" -f $v,$m,$left) -NoNewline >> "%TEMP%\TongMing_dl.ps1"
echo         $last = $left >> "%TEMP%\TongMing_dl.ps1"
echo     } >> "%TEMP%\TongMing_dl.ps1"
echo     Start-Sleep -Milliseconds 100 >> "%TEMP%\TongMing_dl.ps1"
echo } >> "%TEMP%\TongMing_dl.ps1"
echo Write-Host ("`r" + (' '*120)) -NoNewline >> "%TEMP%\TongMing_dl.ps1"
echo Write-Host ("`r  当前版本：{0}" -f $v) -NoNewline >> "%TEMP%\TongMing_dl.ps1"
echo if ($pressed) { >> "%TEMP%\TongMing_dl.ps1"
echo     Start-Sleep -Milliseconds 400 >> "%TEMP%\TongMing_dl.ps1"
echo     try { while ([Console]::KeyAvailable) { [Console]::ReadKey($true) ^| Out-Null } } catch {} >> "%TEMP%\TongMing_dl.ps1"
echo     if (-not $p.HasExited) { $p.Kill() } >> "%TEMP%\TongMing_dl.ps1"
echo     Write-Host '' >> "%TEMP%\TongMing_dl.ps1"
echo     exit 1 >> "%TEMP%\TongMing_dl.ps1"
echo } >> "%TEMP%\TongMing_dl.ps1"
echo if ($p.HasExited -and $p.ExitCode -eq 0) { >> "%TEMP%\TongMing_dl.ps1"
echo     Write-Host '' >> "%TEMP%\TongMing_dl.ps1"
echo     exit 0 >> "%TEMP%\TongMing_dl.ps1"
echo } >> "%TEMP%\TongMing_dl.ps1"
echo if (-not $p.HasExited) { >> "%TEMP%\TongMing_dl.ps1"
echo     $p.Kill() >> "%TEMP%\TongMing_dl.ps1"
echo     Write-Host '' >> "%TEMP%\TongMing_dl.ps1"
echo     exit 2 >> "%TEMP%\TongMing_dl.ps1"
echo } >> "%TEMP%\TongMing_dl.ps1"
echo Write-Host '' >> "%TEMP%\TongMing_dl.ps1"
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
