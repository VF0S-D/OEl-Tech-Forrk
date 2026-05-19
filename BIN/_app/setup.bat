@echo off
setlocal
set "APP=%~dp0"
set "PYDIR=%APP%python"
set "PYEXE=%PYDIR%\python.exe"
set "PYZIP=python-3.12.10-embed-amd64.zip"
set "PYURL=https://www.python.org/ftp/python/3.12.10/%PYZIP%"

echo ============================================================
echo  OP ETERNAL - First-Time Setup
echo  (this runs once and takes a few minutes)
echo ============================================================
echo.

if exist "%PYEXE%" goto :check_pyside6

:: 1. Download embeddable Python
echo Downloading Python 3.12 embeddable...
powershell -NoProfile -Command "Invoke-WebRequest -Uri '%PYURL%' -OutFile '%TEMP%\%PYZIP%'" 2>nul
if not exist "%TEMP%\%PYZIP%" (
    echo ERROR: Failed to download Python.
    echo Make sure you have an internet connection and try again.
    pause & exit /b 1
)

:: 2. Extract
echo Extracting Python...
if not exist "%PYDIR%" mkdir "%PYDIR%"
powershell -NoProfile -Command "Expand-Archive -Path '%TEMP%\%PYZIP%' -DestinationPath '%PYDIR%' -Force"
del "%TEMP%\%PYZIP%" 2>nul
if not exist "%PYEXE%" (
    echo ERROR: Python extraction failed.
    pause & exit /b 1
)

:: 3. Enable pip (uncomment #import site in ._pth)
echo Enabling pip...
powershell -NoProfile -Command ^
    "$p=Get-ChildItem '%PYDIR%' -Filter 'python3*._pth' | Select-Object -First 1; " ^
    "if ($p) { (Get-Content $p.FullName) -replace '#import site','import site' | Set-Content $p.FullName }"

:: 4. Bootstrap pip
echo Installing pip...
if not exist "%PYDIR%\get-pip.py" (
    powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://bootstrap.pypa.io/get-pip.py' -OutFile '%PYDIR%\get-pip.py'"
)
"%PYEXE%" "%PYDIR%\get-pip.py" --no-user --no-warn-script-location
if errorlevel 1 (
    echo ERROR: pip bootstrap failed.
    pause & exit /b 1
)

:check_pyside6
:: 5. Install / verify packages
echo Installing packages (cryptography + PySide6)...
"%PYEXE%" -m pip install --no-user --no-warn-script-location --quiet cryptography PySide6-Essentials
if errorlevel 1 (
    echo ERROR: Package installation failed.
    pause & exit /b 1
)

echo.
echo Setup complete.
echo ============================================================
