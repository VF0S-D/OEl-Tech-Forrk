@echo off
setlocal
set "SRC=%~dp0"

:: Load pinned commits from the shared env file (single source of truth).
if not exist "%SRC%pinned-commits.env" (
    echo ERROR: %SRC%pinned-commits.env not found.
    pause & exit /b 1
)
for /f "usebackq eol=# tokens=1,2 delims==" %%a in ("%SRC%pinned-commits.env") do set "%%a=%%b"

echo ============================================================
echo  ACI-RPCS3 -- Clone source repos at patch baseline
echo ============================================================
echo.

if exist "%SRC%GIT\rpcs3" (
    echo ERROR: GIT\rpcs3 already exists. Run reset-git-repos.bat instead.
    pause & exit /b 1
)
if exist "%SRC%GIT\rpcn" (
    echo ERROR: GIT\rpcn already exists. Run reset-git-repos.bat instead.
    pause & exit /b 1
)

if not exist "%SRC%GIT" mkdir "%SRC%GIT"

:: 1. Clone RPCS3
echo [1/4] Cloning RPCS3 (this may take a while)...
git clone "%RPCS3_URL%" "%SRC%GIT\rpcs3"
if errorlevel 1 ( echo ERROR: RPCS3 clone failed. & pause & exit /b 1 )
echo Done.
echo.

:: 2. Checkout RPCS3 commit and init submodules
echo [2/4] Checking out %RPCS3_COMMIT% and initialising submodules...
cd /d "%SRC%GIT\rpcs3"
git checkout %RPCS3_COMMIT%
if errorlevel 1 ( echo ERROR: RPCS3 checkout failed. & pause & exit /b 1 )
git submodule update --init --recursive
if errorlevel 1 ( echo ERROR: RPCS3 submodule init failed. & pause & exit /b 1 )
echo Done.
echo.

:: 3. Clone RPCN
echo [3/4] Cloning RPCN...
git clone "%RPCN_URL%" "%SRC%GIT\rpcn"
if errorlevel 1 ( echo ERROR: RPCN clone failed. & pause & exit /b 1 )
echo Done.
echo.

:: 4. Checkout RPCN commit
echo [4/4] Checking out %RPCN_COMMIT%...
cd /d "%SRC%GIT\rpcn"
git checkout %RPCN_COMMIT%
if errorlevel 1 ( echo ERROR: RPCN checkout failed. & pause & exit /b 1 )
echo Done.
echo.

echo ============================================================
echo  Both repos cloned. Run apply-patches.bat next.
echo ============================================================
pause
