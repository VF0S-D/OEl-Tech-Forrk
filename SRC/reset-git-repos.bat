@echo off
setlocal
set "SRC=%~dp0"

echo ============================================================
echo  ACI-RPCS3 -- Reset source repos to patch baseline
echo ============================================================
echo.
echo WARNING: This will discard all local modifications and any
echo          applied patches in both repos. Press Ctrl+C to abort.
echo.
pause

:: 1. Reset RPCS3
echo [1/2] Resetting RPCS3...
cd /d "%SRC%GIT\rpcs3"
git reset --hard HEAD
if errorlevel 1 ( echo ERROR: RPCS3 reset failed. & pause & exit /b 1 )
git clean -ffdx
if errorlevel 1 ( echo ERROR: RPCS3 clean failed. & pause & exit /b 1 )
echo Done.
echo.

:: 2. Reset RPCN (also clean new files added by patch)
echo [2/2] Resetting RPCN...
cd /d "%SRC%GIT\rpcn"
git reset --hard HEAD
if errorlevel 1 ( echo ERROR: RPCN reset failed. & pause & exit /b 1 )
git clean -ffdx
if errorlevel 1 ( echo ERROR: RPCN clean failed. & pause & exit /b 1 )
echo Done.
echo.

echo ============================================================
echo  Both repos reset. Ready to run apply-patches.bat.
echo ============================================================
pause
