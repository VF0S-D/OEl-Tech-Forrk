@echo off
setlocal
set "HERE=%~dp0"
set "PYDIR=%HERE%python"
set "PYEXE=%PYDIR%\python.exe"
set "PYVER=3.12.10"
set "PYZIP=python-%PYVER%-embed-amd64.zip"
set "PYURL=https://www.python.org/ftp/python/%PYVER%/%PYZIP%"
set "GETPIP=%PYDIR%\get-pip.py"

if exist "%PYEXE%" goto :install_deps

echo Downloading embeddable Python %PYVER%...
powershell -NoProfile -Command "Invoke-WebRequest -Uri '%PYURL%' -OutFile '%HERE%%PYZIP%'"
if errorlevel 1 ( echo Download failed. & pause & exit /b 1 )

echo Extracting...
if not exist "%PYDIR%" mkdir "%PYDIR%"
powershell -NoProfile -Command "Expand-Archive -Path '%HERE%%PYZIP%' -DestinationPath '%PYDIR%' -Force"
if errorlevel 1 ( echo Extraction failed. & pause & exit /b 1 )
del "%HERE%%PYZIP%"

:: Embeddable Python disables site-packages by default.
:: Uncomment the 'import site' line in the ._pth file so pip works.
powershell -NoProfile -Command ^
    "Get-Item '%PYDIR%\python3*._pth' | ForEach-Object { (Get-Content $_) -replace '^#import site','import site' | Set-Content $_ }"

:install_deps
echo.
echo Installing dependencies...
if not exist "%GETPIP%" (
    powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://bootstrap.pypa.io/get-pip.py' -OutFile '%GETPIP%'"
    if errorlevel 1 ( echo Failed to download get-pip.py. & pause & exit /b 1 )
    "%PYEXE%" "%GETPIP%" --quiet --no-user --no-warn-script-location
    if errorlevel 1 ( echo pip installation failed. & pause & exit /b 1 )
)
"%PYEXE%" -m pip install --quiet --no-user --no-warn-script-location cryptography
if errorlevel 1 ( echo Failed to install cryptography. & pause & exit /b 1 )

echo.
echo Setup complete.
pause
