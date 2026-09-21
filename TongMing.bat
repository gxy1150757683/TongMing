@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

rem ============================================================
rem  TongMing.bat - Online Self-Updating Script + SolidWorks Archive Tool
rem  v1.0.5 维护：提交说明中文化（功能零影响）
rem  NOTE: This file is 100%% ASCII. All Chinese UI text is built
rem  by PowerShell [char]0xXXXX codepoints to avoid GBK/UTF-8
rem  encoding corruption (the root cause of previous failures).
rem
rem  [FLOW]
rem  1. Config zone: LOCAL_VER / VER_URL / SCRIPT_URL
rem  2. Check update: download version file immediately,
rem     show 5s countdown + key-press-skip (all in parallel):
rem       - download done  -> proceed at once (never wait 5s)
rem       - 5s timeout     -> skip, use current version
rem       - any key pressed-> skip immediately
rem  3. Compare versions via PowerShell [version] (by segments)
rem  4. If newer: download new script (same 5s+skip protection)
rem  5. Integrity check: first line must be "@echo off"
rem  5b.FORCE downloaded script's LOCAL_VER to match REMOTE_VER
rem      (prevents infinite update loop if cloud script version
rem       line was not bumped together with version.txt)
rem  6. Self-replace via delayed updater (single window, no flicker)
rem  7. :BUSINESS always reached no matter what
rem  8. This merged file embeds the SolidWorks archive tool business
rem     code in the :PSSECTION section (UTF-8, file saved as UTF-8
rem     WITHOUT BOM so the "@echo off" integrity check still works).
rem
rem  [DISPLAY / NO FLICKER]
rem  - First download call draws the whole screen once (cls+title).
rem    Everything after that ONLY rewrites the version line via CR.
rem  - Single console window (start /b), all UI text is Chinese.
rem ============================================================
set "LOCAL_VER=1.0.5"
set "VER_URL=https://raw.githubusercontent.com/gxy1150757683/TongMing/refs/heads/main/version.txt"
set "SCRIPT_URL=https://raw.githubusercontent.com/gxy1150757683/TongMing/refs/heads/main/TongMing.bat"
set "NEW_FILE=%TEMP%\TongMing_new.bat"
if exist "%TEMP%\TongMing_updater.bat" del /q "%TEMP%\TongMing_updater.bat" >nul 2>&1

rem ============================================================
rem  Step 1: check update (first DLOAD draws screen once)
rem ============================================================
set "URL_PARAM=%VER_URL%?t=%RANDOM%"
set "OUT_PARAM=%TEMP%\TongMing_ver.txt"
set "STYLE_PARAM=1"
call :DLOAD
if "!DL_RESULT!"=="1" (
    call :SHOW 2
    goto :BUSINESS
)
if not "!DL_RESULT!"=="0" (
    call :SHOW 3
    goto :BUSINESS
)

rem ============================================================
rem  Step 2: read remote version (no quoting traps)
rem ============================================================
set "REMOTE_VER="
for /f "usebackq delims=" %%i in ("%TEMP%\TongMing_ver.txt") do if not defined REMOTE_VER set "REMOTE_VER=%%i"
if not defined REMOTE_VER (
    call :SHOW 3
    goto :BUSINESS
)

rem ============================================================
rem  Step 3: compare versions (0=newer 1=same/bad)
rem ============================================================
powershell -NoProfile -Command "$a=[version]'%REMOTE_VER%'; if($a -gt [version]'%LOCAL_VER%'){exit 0}else{exit 1}" 2>nul
if errorlevel 1 goto :NO_UPDATE

rem ============================================================
rem  Step 4: download new script (same countdown+skip)
rem ============================================================
set "URL_PARAM=%SCRIPT_URL%?t=%RANDOM%"
set "OUT_PARAM=%NEW_FILE%"
set "STYLE_PARAM=2"
call :DLOAD
if "!DL_RESULT!"=="1" (
    call :SHOW 4
    goto :BUSINESS
)
if not "!DL_RESULT!"=="0" (
    call :SHOW 5
    goto :BUSINESS
)

rem ============================================================
rem  Step 5: integrity check
rem ============================================================
findstr /b /c:"@echo off" "%NEW_FILE%" >nul 2>&1
if errorlevel 1 (
    call :SHOW 6
    goto :BUSINESS
)

rem ============================================================
rem  Step 5b: FORCE downloaded script's LOCAL_VER = REMOTE_VER
rem  (all double quotes built via [char]34 so the echo line has
rem   NO double quotes -> cmd cannot break it and it never leaks
rem   to the screen)
rem ============================================================
set "PSFIX=%TEMP%\TongMing_fix.ps1"
if exist "%PSFIX%" del "%PSFIX%" >nul 2>&1
echo $f='%NEW_FILE%'                                     >> "%PSFIX%"
echo $r='%REMOTE_VER%'                                   >> "%PSFIX%"
echo $q=[char]34                                         >> "%PSFIX%"
echo $cr=[char]94                                        >> "%PSFIX%"
echo $c=[IO.File]::ReadAllText($f)                       >> "%PSFIX%"
echo $c=[regex]::Replace($c,'set '+$q+'LOCAL_VER=['+$cr+$q+']*'+$q,'set '+$q+'LOCAL_VER='+$r+$q) >> "%PSFIX%"
echo [IO.File]::WriteAllText($f,$c,(New-Object System.Text.UTF8Encoding($false))) >> "%PSFIX%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%PSFIX%" 2>nul
del "%PSFIX%" >nul 2>&1

call :SHOW 1

rem ============================================================
rem  Step 6: single-window self-replace (no self-delete!)
rem ============================================================
(
echo @echo off
echo chcp 936 ^>nul
echo timeout /t 3 /nobreak ^>nul
echo copy /y "%NEW_FILE%" "%~f0" ^>nul
echo if errorlevel 1 exit /b
echo start /b "" cmd /c call "%~f0"
echo exit
) > "%TEMP%\TongMing_updater.bat"

echo.
powershell -NoProfile -Command "Write-Host ([char]0x66F4+[char]0x65B0+[char]0x5B8C+[char]0x6210+[char]0xFF0C+[char]0x5373+[char]0x5C06+[char]0x91CD+[char]0x542F+[char]0x65B0+[char]0x7248+[char]0x672C+[char]0xFF01)" 2>nul
start /b "" "%TEMP%\TongMing_updater.bat"
exit /b

:NO_UPDATE
call :SHOW 0
goto :BUSINESS

rem ============================================================
rem  :SHOW <ID> - rewrite only the version line in place (CR)
rem  ID: 0=up-to-date 1=updated 2=skip 3=check-fail
rem      4=skip-update 5=download-fail 6=bad-content
rem ============================================================
:SHOW
set "SHOW_ID=%~1"
set "PS2=%TEMP%\TongMing_show.ps1"
if exist "%PS2%" del "%PS2%" >nul 2>&1
echo $v='%LOCAL_VER%'                                    >> "%PS2%"
echo $r='%REMOTE_VER%'                                   >> "%PS2%"
echo $id='%SHOW_ID%'                                     >> "%PS2%"
echo $cur='    '+[char]0x5F53+[char]0x524D+[char]0x7248+[char]0x672C+[char]0xFF1A+' '+$v >> "%PS2%"
echo switch($id){                                        >> "%PS2%"
echo  '0'{ $st='      '+[char]0x5DF2+[char]0x4E91+[char]0x7AEF+[char]0x6700+[char]0x65B0+[char]0xFF01 } >> "%PS2%"
echo  '1'{ $st='      '+'('+[char]0x5DF2+[char]0x66F4+[char]0x65B0+')'+[char]0x8FDC+[char]0x7A0B+[char]0x7248+[char]0x672C+':'+$r } >> "%PS2%"
echo  '2'{ $st='      ('+[char]0x5DF2+[char]0x8DF3+[char]0x8FC7+[char]0x66F4+[char]0x65B0+[char]0x68C0+[char]0x6D4B+')' } >> "%PS2%"
echo  '3'{ $st='      ('+[char]0x66F4+[char]0x65B0+[char]0x68C0+[char]0x6D4B+[char]0x5931+[char]0x8D25+[char]0xFF0C+[char]0x4F7F+[char]0x7528+[char]0x5F53+[char]0x524D+[char]0x7248+[char]0x672C+')' } >> "%PS2%"
echo  '4'{ $st='      ('+[char]0x5DF2+[char]0x8DF3+[char]0x8FC7+[char]0x66F4+[char]0x65B0+[char]0xFF0C+[char]0x7EE7+[char]0x7EED+[char]0x4F7F+[char]0x7528+[char]0x5F53+[char]0x524D+[char]0x7248+[char]0x672C+')' } >> "%PS2%"
echo  '5'{ $st='      ('+[char]0x65B0+[char]0x7248+[char]0x672C+[char]0x4E0B+[char]0x8F7D+[char]0x5931+[char]0x8D25+[char]0xFF0C+[char]0x5148+[char]0x4F7F+[char]0x7528+[char]0x5F53+[char]0x524D+[char]0x7248+[char]0x672C+')' } >> "%PS2%"
echo  '6'{ $st='      ('+[char]0x4E0B+[char]0x8F7D+[char]0x5185+[char]0x5BB9+[char]0x5F02+[char]0x5E38+[char]0xFF0C+[char]0x5148+[char]0x4F7F+[char]0x7528+[char]0x5F53+[char]0x524D+[char]0x7248+[char]0x672C+')' } >> "%PS2%"
echo }                                                    >> "%PS2%"
echo Write-Host ([char]13+(' '*110)) -NoNewline           >> "%PS2%"
echo Write-Host ([char]13+$cur+$st) -NoNewline            >> "%PS2%"
echo Write-Host ''                                        >> "%PS2%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS2%" 2>nul
del "%PS2%" >nul 2>&1
exit /b

rem ============================================================
rem  :DLOAD - background download + 5s countdown + key skip
rem  Input : URL_PARAM / OUT_PARAM / STYLE_PARAM(1=first/updating
rem          2=downloading)
rem  Output: DL_RESULT (0=ok 1=key-skipped 2=timeout/fail)
rem  First call (STYLE=1) draws the whole screen once.
rem  Second call (STYLE=2) only rewrites the version line via CR,
rem  so the screen never flickers.
rem ============================================================
:DLOAD
set "PS_FILE=%TEMP%\TongMing_dl.ps1"
if exist "%PS_FILE%" del "%PS_FILE%" >nul 2>&1
echo $h=[char]0x88C5+[char]0x914D+[char]0x4F53+[char]0x5F52+[char]0x6863+[char]0x6574+[char]0x7406+[char]0x5DE5+[char]0x5177+[char]0x5728+[char]0x7EBF+[char]0x66F4+[char]0x65B0+[char]0x811A+[char]0x672C >> "%PS_FILE%"
echo $cv='    '+[char]0x5F53+[char]0x524D+[char]0x7248+[char]0x672C+[char]0xFF1A >> "%PS_FILE%"
echo $sk=[char]0x4EFB+[char]0x610F+[char]0x952E+[char]0x8DF3+[char]0x8FC7 >> "%PS_FILE%"
echo $st='%STYLE_PARAM%'                                >> "%PS_FILE%"
echo $v='%LOCAL_VER%'                                   >> "%PS_FILE%"
echo if($st -eq '1'){ $act=[char]0x66F4+[char]0x65B0+'ing...' }else{ $act=[char]0x4E0B+[char]0x8F7D+[char]0x4E2D+'...' } >> "%PS_FILE%"
echo if($st -eq '1'){ cls }                              >> "%PS_FILE%"
echo if($st -eq '1'){ Write-Host '========================================' } >> "%PS_FILE%"
echo if($st -eq '1'){ Write-Host ('  '+$h) }             >> "%PS_FILE%"
echo if($st -eq '1'){ Write-Host '========================================' } >> "%PS_FILE%"
echo if($st -eq '1'){ Write-Host '' }                    >> "%PS_FILE%"
echo $uri='%URL_PARAM%'                                  >> "%PS_FILE%"
echo $out='%OUT_PARAM%'                                  >> "%PS_FILE%"
echo $d=(Get-Date).AddSeconds(5)                         >> "%PS_FILE%"
echo $last=-1                                            >> "%PS_FILE%"
echo $p=New-Object System.Diagnostics.Process            >> "%PS_FILE%"
echo $p.StartInfo.FileName='curl.exe'                    >> "%PS_FILE%"
echo $p.StartInfo.Arguments='-s -L --connect-timeout 5 --max-time 5 -o '+$out+' '+$uri >> "%PS_FILE%"
echo $p.StartInfo.UseShellExecute=$false                 >> "%PS_FILE%"
echo $p.StartInfo.CreateNoWindow=$true                   >> "%PS_FILE%"
echo try{ $null = $p.Start() }catch{ exit 2 }            >> "%PS_FILE%"
echo Write-Host($cv+' '+$v) -NoNewline                   >> "%PS_FILE%"
echo $keyed=$false                                       >> "%PS_FILE%"
echo while(-not $p.WaitForExit(0) -and (Get-Date) -lt $d){ >> "%PS_FILE%"
echo     $t=$false                                       >> "%PS_FILE%"
echo     try{ $t=[Console]::KeyAvailable }catch{ $t=$false } >> "%PS_FILE%"
echo     if($t){                                         >> "%PS_FILE%"
echo         $keyed=$true                                 >> "%PS_FILE%"
echo         try{ $null=[Console]::ReadKey($true) }catch{} >> "%PS_FILE%"
echo         break                                        >> "%PS_FILE%"
echo     }                                                >> "%PS_FILE%"
echo     $left=[int](($d-(Get-Date)).TotalSeconds)        >> "%PS_FILE%"
echo     if($left -le 0){ $left=1 }                       >> "%PS_FILE%"
echo     if($left -ne $last){                             >> "%PS_FILE%"
echo         Write-Host (([char]13+$cv+' '+$v+' --- '+$act+$left+'s ('+$sk+')')) -NoNewline >> "%PS_FILE%"
echo         $last=$left                                  >> "%PS_FILE%"
echo     }                                                >> "%PS_FILE%"
echo     Start-Sleep -Milliseconds 100                    >> "%PS_FILE%"
echo }                                                    >> "%PS_FILE%"
echo Write-Host ([char]13+(' '*110)) -NoNewline           >> "%PS_FILE%"
echo Write-Host ([char]13+$cv+' '+$v) -NoNewline          >> "%PS_FILE%"
echo if($keyed){                                          >> "%PS_FILE%"
echo     if(-not $p.HasExited){ try{ $p.Kill() }catch{} }  >> "%PS_FILE%"
echo     exit 1                                           >> "%PS_FILE%"
echo }                                                    >> "%PS_FILE%"
echo if($p.HasExited -and $p.ExitCode -eq 0){             >> "%PS_FILE%"
echo     exit 0                                           >> "%PS_FILE%"
echo }                                                    >> "%PS_FILE%"
echo if(-not $p.HasExited){ try{ $p.Kill() }catch{} }     >> "%PS_FILE%"
echo exit 2                                               >> "%PS_FILE%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_FILE%" 2>nul
set "DL_RESULT=!errorlevel!"
del "%PS_FILE%" >nul 2>&1
exit /b

rem ============================================================
rem  BUSINESS ZONE - 装配体归档整理工具（在线更新版）
rem  全局 chcp 65001：与原装配体工具编码方案一致，
rem  业务输出统一 UTF-8，避免代码页中途切换导致的乱码。
rem ============================================================
:BUSINESS
powershell -NoProfile -ExecutionPolicy Bypass -Command "[Console]::OutputEncoding=[Text.Encoding]::UTF8;$batPath='%~f0';$c=[IO.File]::ReadAllText('%~f0',[Text.Encoding]::UTF8);$m=[regex]::Match($c,'(?m)^:PSSECTION\r?$');if($m.Success){$c2=$c.Substring($m.Index);$lines=$c2 -split '\r?\n';if($lines.Count -gt 1){$code=($lines[1..($lines.Length-1)] -join [char]10);Invoke-Expression $code}}"
endlocal
exit /b

:PSSECTION
# ============================================================
#  以下为 PowerShell 核心逻辑（由上方 .bat 提取并执行）
# ============================================================
$ErrorActionPreference = 'Continue'

Add-Type -AssemblyName Microsoft.VisualBasic

# ---------- 常量 ----------
$wordExts = @('.doc','.docx','.docm','.dot','.dotx','.dotm','.rtf','.odt','.wps','.wpt')

# ---------- 基础信息 ----------
$today  = Get-Date -Format 'yyyyMMdd'
$batDir = Split-Path $batPath -Parent

# ---------- 界面辅助 ----------
function Msg($t){ Write-Host $t -ForegroundColor Cyan }
function Info($t){ Write-Host $t -ForegroundColor Yellow }
function Ok($t){ Write-Host $t -ForegroundColor Green }
function Err($t){ Write-Host $t -ForegroundColor Red }

function Confirm-Action([string]$msg){
    # 反向确认：提示"您不删除？"——回车=默认确定不删除；仅输入 否/n 才返回 $true（执行删除）
    $r = Read-Host $msg
    return ($r -match '^(n|no|否)$')
}

function Pick-Index([array]$list,[string]$title){
    Msg $title
    for($i=0;$i -lt $list.Count;$i++){
        Write-Host ("[{0}] {1}" -f ($i+1), $list[$i])
    }
    $n = -1
    while($true){
        $inp = Read-Host ("请输入编号 (1-{0})" -f $list.Count)
        if([int]::TryParse($inp,[ref]$n) -and $n -ge 1 -and $n -le $list.Count){ break }
        Err '输入无效，请重新输入。'
    }
    return $n-1
}

function Read-FunctionInput{
    Write-Host '选择功能（可多选，如 1234 回车执行；0 / ESC / 直接回车 退出）：' -NoNewline
    try{
        $sb = New-Object System.Text.StringBuilder
        while($true){
            $k = [Console]::ReadKey($true)
            if($k.Key -eq [ConsoleKey]::Enter){ Write-Host ''; break }
            if($k.Key -eq [ConsoleKey]::Escape){ return 'ESC' }
            if($k.Key -eq [ConsoleKey]::Backspace){
                if($sb.Length -gt 0){
                    [void]$sb.Remove($sb.Length-1,1)
                    Write-Host -NoNewline "`b `b"
                }
                continue
            }
            $c = $k.KeyChar
            if($c -ge '0' -and $c -le '9'){
                [void]$sb.Append($c)
                Write-Host -NoNewline $c
            }
        }
        return $sb.ToString()
    } catch {
        return (Read-Host)
    }
}

# ---------- 1. 定位顶层装配体 ----------
Write-Host ''
Msg '==================== 定位顶层装配体 ===================='
$candidates = New-Object System.Collections.ArrayList

$upDir  = [System.IO.Path]::GetFullPath((Join-Path $batDir '..'))
$curDir = [System.IO.Path]::GetFullPath($batDir)

foreach($lv in @(@{Name='上级目录';Path=$upDir}, @{Name='本级目录';Path=$curDir})){
    if(Test-Path $lv.Path){
        Get-ChildItem -LiteralPath $lv.Path -Filter *.sldasm -File -ErrorAction SilentlyContinue | ForEach-Object {
            [void]$candidates.Add([pscustomobject]@{Level=$lv.Name; Base=$_.BaseName; Full=$_.FullName})
        }
    }
}
Get-ChildItem -LiteralPath $curDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
    Get-ChildItem -LiteralPath $_.FullName -Filter *.sldasm -File -ErrorAction SilentlyContinue | ForEach-Object {
        [void]$candidates.Add([pscustomobject]@{Level=("下级\" + $_.Directory.Name); Base=$_.BaseName; Full=$_.FullName})
    }
}

if($candidates.Count -eq 0){
    Err '在脚本上/本/下三级目录中未找到任何 .sldasm 文件！'
    Msg '按任意键退出'
    [void][Console]::ReadKey($true)
    exit
}

$noPlus  = @($candidates | Where-Object { $_.Base -notmatch '\+' })
$hasPlus = @($candidates | Where-Object { $_.Base -match '\+' })

$chosen = $null
if($noPlus.Count -eq 1){
    $chosen = $noPlus[0]
} elseif($noPlus.Count -gt 1){
    $idx = Pick-Index ($noPlus | ForEach-Object { "$($_.Level) : $($_.Base)" }) '找到多个不含 + 的 SLDASM，请选择顶层装配体：'
    $chosen = $noPlus[$idx]
} elseif($hasPlus.Count -eq 1){
    Info ("特例：未找到不含 + 的 SLDASM，且仅找到 1 个带 + 的，认定其为顶层装配体：{0}" -f $hasPlus[0].Base)
    $chosen = $hasPlus[0]
} elseif($hasPlus.Count -gt 1){
    $idx = Pick-Index ($hasPlus | ForEach-Object { "$($_.Level) : $($_.Base)" }) '未找到不含 + 的 SLDASM，请从以下带 + 的候选中选择：'
    $chosen = $hasPlus[$idx]
}

$zname  = $chosen.Base
$topDir = Split-Path $chosen.Full -Parent
Ok ("✅ 顶层装配体:{0}" -f $zname)

# ---------- 公共：定位目标文件夹（优先标准名，其次按关键字）----------
function Get-TargetDir($keyword,$stdName){
    $stdPath = Join-Path $topDir $stdName
    if(Test-Path -LiteralPath $stdPath){ return $stdPath }
    $m = Get-ChildItem -LiteralPath $topDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $keyword }
    if($m){ return $m[0].FullName }
    return $null
}
# ---------- 功能1 ----------
function Do-Function1{
    Msg ''
    Msg '======== 功能1：文件夹更新/新建 ========'
    $specs = @(
        @{Kw='打印'; Std=("01-[打印][{0}][{1}]" -f $today,$zname)},
        @{Kw='资料'; Std=("02-[资料][{0}][{1}]" -f $today,$zname)},
        @{Kw='STEP'; Std=("03-[STEP][{0}][{1}]" -f $today,$zname)}
    )
    foreach($sp in $specs){
        $stdPath = Join-Path $topDir $sp.Std
        if(Test-Path -LiteralPath $stdPath){
            Info ("已存在标准文件夹，跳过：{0}" -f $sp.Std)
            $extra = @(Get-ChildItem -LiteralPath $topDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $sp.Kw -and $_.FullName -ne $stdPath })
            if($extra.Count -gt 0){
                Info ("提示：仍有 {0} 个含[{1}]的文件夹未处理，请手动处理：" -f $extra.Count,$sp.Kw)
                foreach($e in $extra){ Info ("    - {0}" -f $e.Name) }
            }
            continue
        }
        $m = @(Get-ChildItem -LiteralPath $topDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match $sp.Kw })
        if($m.Count -eq 0){
            [System.IO.Directory]::CreateDirectory($stdPath) | Out-Null
            Ok ("新建文件夹：{0}" -f $sp.Std)
        } elseif($m.Count -eq 1){
            Rename-Item -LiteralPath $m[0].FullName -NewName $sp.Std
            Ok ("重命名：{0} → {1}" -f $m[0].Name,$sp.Std)
        } else {
            $idx = Pick-Index ($m | ForEach-Object { $_.Name }) ("含[{0}]的文件夹有多个，请选择要重命名的：" -f $sp.Kw)
            Rename-Item -LiteralPath $m[$idx].FullName -NewName $sp.Std
            Ok ("重命名：{0} → {1}" -f $m[$idx].Name,$sp.Std)
            Info ("其余 {0} 个未处理，请手动处理。" -f ($m.Count-1))
        }
    }
    Ok '完成!'
}

# ---------- 功能2 ----------
function Do-Function2{
    Msg ''
    Msg '======== 功能2：删除旧文件（移入回收站）========'
    $printDir = Get-TargetDir '打印' ("01-[打印][{0}][{1}]" -f $today,$zname)
    $dataDir  = Get-TargetDir '资料' ("02-[资料][{0}][{1}]" -f $today,$zname)
    $stepDir  = Get-TargetDir 'STEP' ("03-[STEP][{0}][{1}]" -f $today,$zname)
    $dirs = @()
    if($printDir){ $dirs += [pscustomobject]@{Name='打印文件夹';Path=$printDir} }
    if($dataDir){  $dirs += [pscustomobject]@{Name='资料文件夹';Path=$dataDir} }
    if($stepDir){  $dirs += [pscustomobject]@{Name='STEP文件夹';Path=$stepDir} }
    if($dirs.Count -eq 0){ Err '未找到任何目标文件夹（打印/资料/STEP），跳过功能2。'; return }

    Write-Host '以下文件夹内的文件将被移入回收站：'
    foreach($d in $dirs){ Write-Host ("  - {0}：{1}" -f $d.Name,$d.Path) }
    Info '例外：打印文件夹内的 Word 文件（doc/docx/docm/dot/dotx/dotm/rtf/odt/wps/wpt）不删除。'
    if(-not (Confirm-Action '您不删除？（回车=不删除；输入 n/否=执行删除）：')){
        Info '已取消功能2。'
        return
    }

    $isPrintDir = [System.IO.Path]::GetFullPath($printDir)
    foreach($d in $dirs){
        $curIsPrint = ([System.IO.Path]::GetFullPath($d.Path) -eq $isPrintDir)
        foreach($file in (Get-ChildItem -LiteralPath $d.Path -File -ErrorAction SilentlyContinue)){
            $ext = $file.Extension.ToLower()
            if($curIsPrint -and ($wordExts -contains $ext)){
                Ok ("保留(Word)：{0}" -f $file.Name)
                continue
            }
            try{
                [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($file.FullName, [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs, [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin, [Microsoft.VisualBasic.FileIO.UICancelOption]::ThrowException)
                Ok ("已删除：{0}" -f $file.Name)
            } catch {
                Err ("删除失败：{0}（{1}）" -f $file.Name,$_.Exception.Message)
            }
        }
    }
    Ok '完成!'
}

# ---------- 功能3 ----------
function Do-Function3{
    Msg ''
    Msg '======== 功能3：文件归档 ========'
    $printDir = Get-TargetDir '打印' ("01-[打印][{0}][{1}]" -f $today,$zname)
    $dataDir  = Get-TargetDir '资料' ("02-[资料][{0}][{1}]" -f $today,$zname)
    $stepDir  = Get-TargetDir 'STEP' ("03-[STEP][{0}][{1}]" -f $today,$zname)
    if(-not $printDir){
        $printDir = Join-Path $topDir ("01-[打印][{0}][{1}]" -f $today,$zname)
        [System.IO.Directory]::CreateDirectory($printDir) | Out-Null
        Info ("自动创建打印文件夹：{0}" -f $printDir)
    }
    if(-not $dataDir){
        $dataDir = Join-Path $topDir ("02-[资料][{0}][{1}]" -f $today,$zname)
        [System.IO.Directory]::CreateDirectory($dataDir) | Out-Null
        Info ("自动创建资料文件夹：{0}" -f $dataDir)
    }
    if(-not $stepDir){
        $stepDir = Join-Path $topDir ("03-[STEP][{0}][{1}]" -f $today,$zname)
        [System.IO.Directory]::CreateDirectory($stepDir) | Out-Null
        Info ("自动创建STEP文件夹：{0}" -f $stepDir)
    }

    $files = @(Get-ChildItem -LiteralPath $topDir -File -ErrorAction SilentlyContinue)
    if($files.Count -eq 0){ Info '顶装本目录下没有散文件，跳过。'; return }
    foreach($f in $files){
        if($f.FullName -eq $batPath){ continue }
        $ext = $f.Extension.ToLower()
        if($ext -eq '.sldasm' -or $ext -eq '.sldprt' -or $ext -eq '.slddrw'){
            continue
        }
        if($ext -eq '.pdf' -or ($wordExts -contains $ext)){ $dest = $printDir }
        elseif($ext -eq '.step' -or $ext -eq '.stp'){ $dest = $stepDir }
        else { $dest = $dataDir }

        $destPath = Join-Path $dest $f.Name
        try{
            if(Test-Path -LiteralPath $destPath){
                [Microsoft.VisualBasic.FileIO.FileSystem]::MoveFile($f.FullName,$destPath,[Microsoft.VisualBasic.FileIO.UIOption]::AllDialogs,[Microsoft.VisualBasic.FileIO.UICancelOption]::ThrowException)
            } else {
                [Microsoft.VisualBasic.FileIO.FileSystem]::MoveFile($f.FullName,$destPath,[Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,[Microsoft.VisualBasic.FileIO.UICancelOption]::ThrowException)
            }
            Ok ("移动：{0} → {1}" -f $f.Name,(Split-Path $dest -Leaf))
        } catch {
            Err ("移动失败/跳过：{0}（{1}）" -f $f.Name,$_.Exception.Message)
        }
    }
    Ok '完成!'
}

# ---------- 功能4 ----------
function Do-Function4{
    Msg ''
    Msg '======== 功能4：同名（打印文件夹内文件改名为顶层装配体名）========'
    $printDir = Get-TargetDir '打印' ("01-[打印][{0}][{1}]" -f $today,$zname)
    if(-not $printDir){ Err '未找到打印文件夹，跳过功能4。'; return }
    $files = @(Get-ChildItem -LiteralPath $printDir -File -ErrorAction SilentlyContinue)
    if($files.Count -eq 0){ Info '打印文件夹内没有文件，跳过。'; return }
    $nRenamed=0; $nSkipSame=0; $nSkipBat=0
    foreach($f in $files){
        if($f.Extension.ToLower() -eq '.bat'){ $nSkipBat++; continue }
        $target = $zname + $f.Extension
        if($f.Name -eq $target){
            $nSkipSame++
            Info ("跳过同名：   {0}" -f $f.Name)
            continue
        }
        $destPath = Join-Path $printDir $target
        try{
            if(Test-Path -LiteralPath $destPath){
                [Microsoft.VisualBasic.FileIO.FileSystem]::MoveFile($f.FullName,$destPath,[Microsoft.VisualBasic.FileIO.UIOption]::AllDialogs,[Microsoft.VisualBasic.FileIO.UICancelOption]::ThrowException)
            } else {
                [Microsoft.VisualBasic.FileIO.FileSystem]::MoveFile($f.FullName,$destPath,[Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,[Microsoft.VisualBasic.FileIO.UICancelOption]::ThrowException)
            }
            $nRenamed++
            Ok ("重命名：    {0} → {1}" -f $f.Name,$target)
        } catch {
            Err ("重命名失败：{0}（{1}）" -f $f.Name,$_.Exception.Message)
        }
    }
    if($nSkipBat -gt 0){ Info ("排除：    .bat {0} 个" -f $nSkipBat) }
    Write-Host ''
    Ok '完成!'
}

# ---------- 执行（菜单显示一次，执行完可直接继续输入）----------
Write-Host ''
Msg '==================== 功能菜单 ===================='
Write-Host '  1 = 功能1  文件夹更新/新建（01打印 / 02资料 / 03STEP）'
Write-Host '  2 = 功能2  删除旧文件（移入回收站，打印夹内Word除外）'
Write-Host '  3 = 功能3  文件归档（顶装本散文件分类归入三个文件夹）'
Write-Host '  4 = 功能4  同名（打印文件夹内所有文件改名为顶层装配体名）'
Write-Host '  0 / ESC / 直接回车 = 退出'

while($true){
    Write-Host ''
    $sel = Read-FunctionInput
    if($sel -eq 'ESC' -or $sel.Length -eq 0){ Ok '已退出工具，再见！'; break }
    $toRun = @()
    $wantExit = $false
    for($i=0;$i -lt $sel.Length;$i++){
        $ch = $sel.Substring($i,1)
        if($ch -eq '0'){ $wantExit = $true; break }
        if($ch -match '[1-4]' -and ($toRun -notcontains $ch)){ $toRun += $ch }
    }
    if($wantExit){ Ok '已退出工具，再见！'; break }
    if($toRun.Count -eq 0){
        Info '未输入有效功能（可多选，如 1234 回车执行；0 / ESC / 直接回车 退出）'
        continue
    }
    foreach($f in @('1','2','3','4')){
        if($toRun -contains $f){
            switch($f){
                '1' { Do-Function1 }
                '2' { Do-Function2 }
                '3' { Do-Function3 }
                '4' { Do-Function4 }
            }
        }
    }
    Write-Host ''
    Ok '全部执行成功！！！'
}

