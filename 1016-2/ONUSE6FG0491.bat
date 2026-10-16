@echo off
setlocal
cd /d "%~dp0"

rem ===== Pass 1: cari kelompok terkecil =====
set "MIN="
for %%F in (*_*) do call :cari "%%~nF"
if not defined MIN (
    echo Tidak ada file dengan format angka_xxx.
    pause
    exit /b
)

rem ===== Pass 2: pindahkan file ke folder 1, 2, 3, ... =====
for %%F in (*_*) do call :pindah "%%~fF" "%%~nF"

echo Selesai.
pause
exit /b


:ambil
rem Ambil angka sebelum "_" lalu hitung kelompok (tiap 5 angka: 1-5, 6-10, ...)
set "G="
set "P="
for /f "tokens=1 delims=_" %%A in ("%~1") do set "P=%%A"
if not defined P exit /b
echo "%P%"| findstr /r "^\"[0-9][0-9]*\"$" >nul || exit /b
rem buang nol di depan supaya tidak dibaca sebagai oktal
set "N="
for /f "tokens=* delims=0" %%Z in ("%P%") do set "N=%%Z"
if not defined N set "N=0"
set /a G=(N-1)/5
exit /b


:cari
call :ambil "%~1"
if not defined G exit /b
if not defined MIN (
    set "MIN=%G%"
    exit /b
)
if %G% LSS %MIN% set "MIN=%G%"
exit /b


:pindah
if /i "%~1"=="%~f0" exit /b
call :ambil "%~2"
if not defined G exit /b
set /a FOLDER=G-MIN+1
if not exist "%FOLDER%\" mkdir "%FOLDER%"
move "%~1" "%FOLDER%\" >nul
echo %~nx1  -^>  %FOLDER%
exit /b
