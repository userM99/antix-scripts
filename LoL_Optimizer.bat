@echo off
title LoL PC Optimizer - CMD verzija
color 0A
chcp 65001 >nul 2>&1

:: ============================================================
::   LoL PC OPTIMIZER - CMD/Batch verzija
::   Pokreni kao Administrator!
:: ============================================================

:: Provjera Admin prava
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo  [!] GRESKA: Pokreni kao ADMINISTRATOR!
    echo  [!] Desni klik na fajl - Run as Administrator
    echo.
    pause
    exit /b
)

:MENU
cls
echo.
echo  +==================================================+
echo  ^|         LoL PC OPTIMIZER  v1.0  [CMD]           ^|
echo  ^|      Maksimalna optimizacija za gaming           ^|
echo  +==================================================+
echo.
echo  [1] Pokreni PUNU optimizaciju (preporuceno)
echo  [2] Samo ocisti TEMP i Prefetch
echo  [3] Samo Registry tweaks
echo  [4] Samo oslobodi RAM
echo  [5] Samo CPU optimizacija
echo  [6] Izlaz
echo.
set /p izbor="  Odaberi opciju (1-6): "

if "%izbor%"=="1" goto FULL
if "%izbor%"=="2" goto TEMP
if "%izbor%"=="3" goto REGISTRY
if "%izbor%"=="4" goto RAM
if "%izbor%"=="5" goto CPU
if "%izbor%"=="6" exit /b
goto MENU

:: ════════════════════════════════════════════════════════════
:FULL
:: ════════════════════════════════════════════════════════════
cls
echo.
echo  +==================================================+
echo  ^|          POKRECEMO PUNU OPTIMIZACIJU...          ^|
echo  +==================================================+
echo.

:: ────────────────────────────────────────────────────────────
echo  [1/6] Cistim TEMP foldere...
:: ────────────────────────────────────────────────────────────

:: Ubij explorer privremeno da bi se oslobodili fajlovi
taskkill /f /im explorer.exe >nul 2>&1

:: Brisi temp foldere
del /f /s /q "%TEMP%\*" >nul 2>&1
del /f /s /q "%TMP%\*" >nul 2>&1
del /f /s /q "C:\Windows\Temp\*" >nul 2>&1
del /f /s /q "C:\Windows\Prefetch\*" >nul 2>&1

:: Obrisi prazne podfoldere
for /d %%i in ("%TEMP%\*") do rd /s /q "%%i" >nul 2>&1
for /d %%i in ("C:\Windows\Temp\*") do rd /s /q "%%i" >nul 2>&1
for /d %%i in ("C:\Windows\Prefetch\*") do rd /s /q "%%i" >nul 2>&1

:: Vrati explorer
start explorer.exe

echo     OK - TEMP i Prefetch ocisceni
echo.

:: ────────────────────────────────────────────────────────────
echo  [2/6] Primjenjujem Registry optimizacije...
:: ────────────────────────────────────────────────────────────

:: Game DVR iskljuci
reg add "HKCU\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\System\GameConfigStore" /v "GameDVR_FSEBehaviorMode" /t REG_DWORD /d 2 /f >nul 2>&1
echo     OK - Game DVR onemogucen

:: Game Mode ukljuci
reg add "HKCU\Software\Microsoft\GameBar" /v "AllowAutoGameMode" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\GameBar" /v "AutoGameModeEnabled" /t REG_DWORD /d 1 /f >nul 2>&1
echo     OK - Game Mode ukljucen

:: QoS - oslobodi 100% bandwidth
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v "NonBestEffortLimit" /t REG_DWORD /d 0 /f >nul 2>&1
echo     OK - Mrezni QoS optimizovan (0%% rezervisan)

:: Vizuelni efekti - Performanse
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v "VisualFXSetting" /t REG_DWORD /d 2 /f >nul 2>&1
echo     OK - Vizuelni efekti: Performanse

:: Mouse acceleration iskljuci
reg add "HKCU\Control Panel\Mouse" /v "MouseSpeed" /t REG_SZ /d "0" /f >nul 2>&1
reg add "HKCU\Control Panel\Mouse" /v "MouseThreshold1" /t REG_SZ /d "0" /f >nul 2>&1
reg add "HKCU\Control Panel\Mouse" /v "MouseThreshold2" /t REG_SZ /d "0" /f >nul 2>&1
echo     OK - Mouse Acceleration onemogucen

:: Nagle algoritam - smanji ping
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "TcpAckFrequency" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "TCPNoDelay" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "TcpDelAckTicks" /t REG_DWORD /d 0 /f >nul 2>&1
echo     OK - Nagle algoritam onemogucen (manji ping)

:: Notification i background apps iskljuci
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v "GlobalUserDisabled" /t REG_DWORD /d 1 /f >nul 2>&1
echo     OK - Background apps onemogucene
echo.

:: ────────────────────────────────────────────────────────────
echo  [3/6] Oslobadjam RAM...
:: ────────────────────────────────────────────────────────────

:: Zatvori nepotrebne procese
taskkill /f /im OneDrive.exe >nul 2>&1 && echo     OK - Zatvoren: OneDrive
taskkill /f /im Teams.exe >nul 2>&1 && echo     OK - Zatvoren: Teams
taskkill /f /im Cortana.exe >nul 2>&1 && echo     OK - Zatvoren: Cortana
taskkill /f /im YourPhone.exe >nul 2>&1 && echo     OK - Zatvoren: YourPhone
taskkill /f /im Spotify.exe >nul 2>&1 && echo     OK - Zatvoren: Spotify
taskkill /f /im SearchApp.exe >nul 2>&1 && echo     OK - Zatvoren: SearchApp
echo.

:: ────────────────────────────────────────────────────────────
echo  [4/6] CPU optimizacija...
:: ────────────────────────────────────────────────────────────

:: High Performance power plan
powercfg -setactive SCHEME_MIN >nul 2>&1
echo     OK - Power plan: High Performance

:: CPU bez throttlinga
powercfg -setacvalueindex SCHEME_MIN SUB_PROCESSOR PROCTHROTTLEMIN 100 >nul 2>&1
powercfg -setacvalueindex SCHEME_MIN SUB_PROCESSOR PROCTHROTTLEMAX 100 >nul 2>&1
powercfg -s SCHEME_MIN >nul 2>&1
echo     OK - CPU: 100%% performanse, bez throttlinga

:: Ako je LoL pokrenut, daj mu HIGH prioritet
wmic process where name="League of Legends.exe" CALL setpriority "high priority" >nul 2>&1
wmic process where name="LeagueClient.exe" CALL setpriority "high priority" >nul 2>&1
echo     OK - LoL procesi: HIGH prioritet (ako su pokrenuti)
echo.

:: ────────────────────────────────────────────────────────────
echo  [5/6] Pauziram nepotrebne Windows servise...
:: ────────────────────────────────────────────────────────────

net stop "SysMain" >nul 2>&1 && echo     OK - Pauziran: SysMain (Superfetch)
net stop "DiagTrack" >nul 2>&1 && echo     OK - Pauziran: DiagTrack (Telemetrija)
net stop "WSearch" >nul 2>&1 && echo     OK - Pauziran: WSearch (Indeksiranje)
echo.

:: ────────────────────────────────────────────────────────────
echo  [6/6] DNS flush i mreza...
:: ────────────────────────────────────────────────────────────

ipconfig /flushdns >nul 2>&1
echo     OK - DNS cache ociscen

:: TCP optimizacija
netsh int tcp set global autotuninglevel=normal >nul 2>&1
netsh int tcp set global chimney=enabled >nul 2>&1
netsh int tcp set global dca=enabled >nul 2>&1
netsh int tcp set global netdma=enabled >nul 2>&1
netsh int tcp set global ecncapability=disabled >nul 2>&1
echo     OK - TCP/IP mreza optimizovana

:: Disk cleanup
cleanmgr /sagerun:1 >nul 2>&1
echo     OK - Disk Cleanup pokrenut u pozadini
echo.

goto DONE

:: ════════════════════════════════════════════════════════════
:TEMP
:: ════════════════════════════════════════════════════════════
cls
echo.
echo  Cistim TEMP i Prefetch...
echo.
taskkill /f /im explorer.exe >nul 2>&1
del /f /s /q "%TEMP%\*" >nul 2>&1
del /f /s /q "%TMP%\*" >nul 2>&1
del /f /s /q "C:\Windows\Temp\*" >nul 2>&1
del /f /s /q "C:\Windows\Prefetch\*" >nul 2>&1
for /d %%i in ("%TEMP%\*") do rd /s /q "%%i" >nul 2>&1
for /d %%i in ("C:\Windows\Temp\*") do rd /s /q "%%i" >nul 2>&1
start explorer.exe
echo  OK - TEMP i Prefetch ocisceni!
goto DONE

:: ════════════════════════════════════════════════════════════
:REGISTRY
:: ════════════════════════════════════════════════════════════
cls
echo.
echo  Primjenjujem Registry tweaks...
echo.
reg add "HKCU\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Software\Microsoft\GameBar" /v "AutoGameModeEnabled" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Psched" /v "NonBestEffortLimit" /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKCU\Control Panel\Mouse" /v "MouseSpeed" /t REG_SZ /d "0" /f >nul 2>&1
reg add "HKCU\Control Panel\Mouse" /v "MouseThreshold1" /t REG_SZ /d "0" /f >nul 2>&1
reg add "HKCU\Control Panel\Mouse" /v "MouseThreshold2" /t REG_SZ /d "0" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "TcpAckFrequency" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" /v "TCPNoDelay" /t REG_DWORD /d 1 /f >nul 2>&1
echo  OK - Registry tweaks primijenjeni!
goto DONE

:: ════════════════════════════════════════════════════════════
:RAM
:: ════════════════════════════════════════════════════════════
cls
echo.
echo  Oslobadjam RAM...
echo.
taskkill /f /im OneDrive.exe >nul 2>&1
taskkill /f /im Teams.exe >nul 2>&1
taskkill /f /im Cortana.exe >nul 2>&1
taskkill /f /im Spotify.exe >nul 2>&1
taskkill /f /im SearchApp.exe >nul 2>&1
taskkill /f /im YourPhone.exe >nul 2>&1
echo  OK - Nepotrebni procesi zatvoreni!
goto DONE

:: ════════════════════════════════════════════════════════════
:CPU
:: ════════════════════════════════════════════════════════════
cls
echo.
echo  CPU optimizacija...
echo.
powercfg -setactive SCHEME_MIN >nul 2>&1
powercfg -setacvalueindex SCHEME_MIN SUB_PROCESSOR PROCTHROTTLEMIN 100 >nul 2>&1
powercfg -setacvalueindex SCHEME_MIN SUB_PROCESSOR PROCTHROTTLEMAX 100 >nul 2>&1
powercfg -s SCHEME_MIN >nul 2>&1
wmic process where name="League of Legends.exe" CALL setpriority "high priority" >nul 2>&1
echo  OK - CPU na High Performance, bez throttlinga!
goto DONE

:: ════════════════════════════════════════════════════════════
:DONE
:: ════════════════════════════════════════════════════════════
echo.
echo  +==================================================+
echo  ^|   OPTIMIZACIJA ZAVRSENA!  GG WP, good luck!     ^|
echo  +==================================================+
echo.
echo  Servisi ce se resetovati pri restartovanju.
echo  Pokreni skriptu ponovo prije svakog LoL-a!
echo.
echo  Pritisni bilo koji taster za povratak u meni...
pause >nul
goto MENU
