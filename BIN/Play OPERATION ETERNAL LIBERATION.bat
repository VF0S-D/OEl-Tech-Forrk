@echo off
cd /d "%~dp0"

:: First-run setup if Python is missing
if not exist "_app\python\pythonw.exe" (
    call "_app\setup.bat"
    if not exist "_app\python\pythonw.exe" (
        echo Setup failed. See above for details.
        pause & exit /b 1
    )
)

start "" "_app\python\pythonw.exe" "_app\launcher.py"
