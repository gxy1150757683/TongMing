@echo off
setlocal enabledelayedexpansion
chcp 936 >nul

rem ============================================================
rem  TongMing.bat - Online Self-Updating Script
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
rem
rem  [DISPLAY / NO FLICKER]
rem  - First download call draws the whole screen once (cls+title).
rem    Everything after that ONLY rewrites the version line via CR.
rem  - Single console window (start /b), all UI text is Chinese.
rem ============================================================
set "LOCAL_VER=1.0.1"
set "VER_URL=https://raw.githubusercontent.com/gxy1150757683/TongMing/refs/heads/main/version.txt"
set "SCRIPT_URL=https://raw.githubusercontent.com/gxy1150757683/TongMing/refs/heads/main/TongMing.bat"
set "NEW_FILE=%TEMP%\TongMing_new.bat"
if exist "%TEMP%\TongMing_updater.bat" del /q "%TEMP%\TongMing_updater.bat" >nul 2>&1

rem ============================================================
rem  Step 1: check update (first DLOAD draws screen once)
rem ============================================================
set "URL_PARAM=%VER_URL%"
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
set "URL_PARAM=%SCRIPT_URL%"
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
echo [IO.File]::WriteAllText($f,$c,[Text.Encoding]::ASCII) >> "%PSFIX%"
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
echo $h='TongMing '+[char]0x5728+[char]0x7EBF+[char]0x66F4+[char]0x65B0+[char]0x811A+[char]0x672C >> "%PS_FILE%"
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
rem  BUSINESS ZONE - your own code below.
rem  (Keep system area above untouched. If you add Chinese here
rem   and it shows garbled, save the file as GBK/ANSI.)
rem ============================================================
:BUSINESS
echo ========================================
echo   Your business code here
echo ========================================
echo.
rem pause below is for debug only; remove in production
pause
exit /b
