@echo off
setlocal
title Upload Folder ke GitHub

REM ===== Cek Git =====
where git >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Git belum terpasang. Download dulu di https://git-scm.com/download/win
  pause
  exit /b 1
)

set "BASE=%USERPROFILE%\git_uploads"
if not exist "%BASE%" mkdir "%BASE%"

REM ===== Pilih folder lewat jendela File Explorer =====
echo Pilih folder yang mau di-push...
set "SRC="
for /f "usebackq delims=" %%i in (`powershell -NoProfile -STA -ExecutionPolicy Bypass -Command "$c=[IO.File]::ReadAllText('%~f0'); iex $c.Substring($c.LastIndexOf('#==PS==')+7)"`) do set "SRC=%%i"
if not defined SRC (
  echo Dibatalkan, tidak ada folder dipilih.
  pause
  exit /b 0
)

REM ===== Popup input repo =====
set "REPO="
for /f "usebackq delims=" %%i in (`powershell -NoProfile -Command "Add-Type -AssemblyName Microsoft.VisualBasic; $p=[Environment]::GetFolderPath('UserProfile')+'\git_uploads\last_repo.txt'; $d='https://github.com/glidingcoast/daily_upload.git'; if(Test-Path $p){$d=(Get-Content $p -TotalCount 1).Trim()}; [Microsoft.VisualBasic.Interaction]::InputBox('Masukkan URL repo GitHub tujuan:','Pilih Repo',$d)"`) do set "REPO=%%i"
if not defined REPO (
  echo Dibatalkan, URL repo kosong.
  pause
  exit /b 0
)
>"%BASE%\last_repo.txt" echo %REPO%

REM ===== Nama folder & nama repo =====
for %%A in ("%SRC%") do set "FNAME=%%~nxA"
for %%A in ("%REPO%") do set "RNAME=%%~nA"
set "DEST=%BASE%\%RNAME%"

echo.
echo Folder : %SRC%
echo Repo   : %REPO%
echo Hasil  : %RNAME%/%FNAME%/...
echo.

REM ===== Clone repo kalau belum ada =====
if not exist "%DEST%\.git" (
  echo Mengambil repo dari GitHub...
  git clone "%REPO%" "%DEST%"
  if errorlevel 1 (
    echo.
    echo [ERROR] Gagal clone repo. Cek URL repo dan koneksi internet.
    pause
    exit /b 1
  )
)

cd /d "%DEST%"
git remote set-url origin "%REPO%"

REM ===== Tentukan branch: ikuti branch yang ada di GitHub =====
set "BR="
git ls-remote --exit-code --heads origin main >nul 2>nul
if not errorlevel 1 set "BR=main"
if not defined BR (
  git ls-remote --exit-code --heads origin master >nul 2>nul
  if not errorlevel 1 set "BR=master"
)
set "REMOTE_HAS_BRANCH=1"
if not defined BR (
  set "BR=main"
  set "REMOTE_HAS_BRANCH=0"
)

REM Batalkan rebase yang mungkin nyangkut dari percobaan sebelumnya
git rebase --abort >nul 2>nul

REM Samakan nama branch lokal dengan branch di GitHub
git checkout -B "%BR%" >nul 2>nul
if errorlevel 1 git symbolic-ref HEAD "refs/heads/%BR%"

REM ===== Ambil update terbaru dari GitHub =====
if "%REMOTE_HAS_BRANCH%"=="1" (
  echo Mengambil update terbaru dari GitHub...
  git fetch origin "%BR%"
  git branch --set-upstream-to="origin/%BR%" "%BR%" >nul 2>nul
  git pull --rebase origin "%BR%" >nul 2>nul
  if errorlevel 1 (
    git rebase --abort >nul 2>nul
    git pull --no-rebase --allow-unrelated-histories --no-edit origin "%BR%"
  )
)

REM ===== Salin folder beserta foldernya =====
echo Menyalin folder %FNAME%...
robocopy "%SRC%" "%DEST%\%FNAME%" /E /XD .git /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 (
  echo [ERROR] Gagal menyalin folder.
  pause
  exit /b 1
)

REM ===== Commit =====
git add -A -- "%FNAME%"
git commit -m "Upload %FNAME%"
if errorlevel 1 echo Tidak ada perubahan baru untuk di-commit.

REM ===== Push, kalau ditolak: tarik update dulu lalu push ulang =====
echo.
echo Push ke GitHub...
git push -u origin "%BR%"
if not errorlevel 1 goto :sukses

echo.
echo Push ditolak, menyamakan dengan versi di GitHub lalu mencoba lagi...
git pull --rebase origin "%BR%"
if errorlevel 1 (
  git rebase --abort >nul 2>nul
  git pull --no-rebase --allow-unrelated-histories --no-edit origin "%BR%"
)
git push -u origin "%BR%"
if not errorlevel 1 goto :sukses

echo.
echo [GAGAL] Push tetap tidak berhasil. Kirim pesan error di atas untuk dicek.
echo.
pause
exit /b 1

:sukses
echo.
echo [BERHASIL] Folder %FNAME% sudah ter-upload ke %REPO%
echo.
pause
exit /b 0

REM Bagian di bawah ini dijalankan oleh PowerShell (jendela pilih folder ala File Explorer)
#==PS==
$cs = @'
using System;
using System.Runtime.InteropServices;

[ComImport, Guid("DC1C5A9C-E88A-4dde-A5A1-60F82A20AEF7")]
internal class FileOpenDialogRCW {}

[ComImport, Guid("43826D1E-E718-42EE-BC55-A1E261C37BFE"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
internal interface IShellItem {
    void BindToHandler();
    void GetParent();
    void GetDisplayName(uint sigdnName, [MarshalAs(UnmanagedType.LPWStr)] out string ppszName);
    void GetAttributes();
    void Compare();
}

[ComImport, Guid("42f85136-db7e-439c-85f1-e4075d135fc8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
internal interface IFileOpenDialog {
    [PreserveSig] int Show(IntPtr hwnd);
    void SetFileTypes();
    void SetFileTypeIndex();
    void GetFileTypeIndex();
    void Advise();
    void Unadvise();
    void SetOptions(uint fos);
    void GetOptions(out uint fos);
    void SetDefaultFolder(IShellItem psi);
    void SetFolder(IShellItem psi);
    void GetFolder();
    void GetCurrentSelection();
    void SetFileName();
    void GetFileName();
    void SetTitle([MarshalAs(UnmanagedType.LPWStr)] string pszTitle);
    void SetOkButtonLabel([MarshalAs(UnmanagedType.LPWStr)] string pszText);
    void SetFileNameLabel();
    void GetResult(out IShellItem ppsi);
}

public static class FolderPicker {
    [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = false)]
    private static extern void SHCreateItemFromParsingName(string pszPath, IntPtr pbc,
        [In, MarshalAs(UnmanagedType.LPStruct)] Guid riid, out IShellItem ppv);

    [DllImport("kernel32.dll")]
    private static extern IntPtr GetConsoleWindow();

    public static string Pick(string title, string startPath) {
        IFileOpenDialog dlg = (IFileOpenDialog)new FileOpenDialogRCW();
        uint opts;
        dlg.GetOptions(out opts);
        dlg.SetOptions(opts | 0x20 | 0x40); // pilih folder, hanya folder di disk
        dlg.SetTitle(title);
        dlg.SetOkButtonLabel("Pilih Folder");
        if (System.IO.Directory.Exists(startPath)) {
            IShellItem start;
            SHCreateItemFromParsingName(startPath, IntPtr.Zero, typeof(IShellItem).GUID, out start);
            dlg.SetFolder(start);
        }
        if (dlg.Show(GetConsoleWindow()) != 0) return null;
        IShellItem result;
        dlg.GetResult(out result);
        string path;
        result.GetDisplayName(0x80058000, out path);
        return path;
    }
}
'@
Add-Type -TypeDefinition $cs
$picked = [FolderPicker]::Pick('Pilih folder yang mau di-push ke GitHub', (Join-Path $env:USERPROFILE 'Downloads'))
if ($picked) { $picked }