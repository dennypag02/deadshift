@echo off
setlocal
cd /d "%~dp0"

echo.
echo ===============================================
echo   DeadShift Local Asset Worker - One-Time Setup
echo ===============================================
echo.

where git >nul 2>&1
if errorlevel 1 (
  echo ERROR: Git was not found.
  pause
  exit /b 1
)

where python >nul 2>&1
if errorlevel 1 (
  echo ERROR: Python was not found.
  pause
  exit /b 1
)

echo Updating DeadShift...
git -C .. switch feature/asset-pipeline-step1
if errorlevel 1 goto :gitfail

git -C .. pull --ff-only origin feature/asset-pipeline-step1
if errorlevel 1 goto :gitfail

echo Checking required Python packages...
python -c "import requests, yaml; from PIL import Image" >nul 2>&1
if errorlevel 1 (
  echo Installing the three approved local packages...
  python -m pip install requests Pillow pyyaml
  if errorlevel 1 (
    echo ERROR: Python package setup failed.
    pause
    exit /b 1
  )
)

for /f "delims=" %%P in ('python -c "import os,sys; print(os.path.join(os.path.dirname(sys.executable),'pythonw.exe'))"') do set "PYTHONW=%%P"

if not exist "%PYTHONW%" (
  echo ERROR: pythonw.exe was not found at:
  echo %PYTHONW%
  pause
  exit /b 1
)

set "WORKER_SCRIPT=%CD%\local_worker.py"
set "WORKER_CWD=%CD%"
set "STARTUP_LINK=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\DeadShift Asset Worker.lnk"

echo Creating Windows startup shortcut...
set "DS_PYTHONW=%PYTHONW%"
set "DS_WORKER_SCRIPT=%WORKER_SCRIPT%"
set "DS_WORKER_CWD=%WORKER_CWD%"
set "DS_STARTUP_LINK=%STARTUP_LINK%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$w=New-Object -ComObject WScript.Shell; $s=$w.CreateShortcut($env:DS_STARTUP_LINK); $s.TargetPath=$env:DS_PYTHONW; $s.Arguments='"' + $env:DS_WORKER_SCRIPT + '"'; $s.WorkingDirectory=$env:DS_WORKER_CWD; $s.WindowStyle=7; $s.Description='DeadShift local asset generation worker'; $s.Save()"

if errorlevel 1 (
  echo ERROR: Could not create startup shortcut.
  pause
  exit /b 1
)

echo Starting worker...
start "" "%PYTHONW%" "%WORKER_SCRIPT%"

echo Waiting for local review server...
timeout /t 3 /nobreak >nul
start "" "http://127.0.0.1:8765/"

echo.
echo ===============================================
echo Setup complete.
echo.
echo From now on:
echo   1. Keep ComfyUI Desktop open when generating art.
echo   2. Tell ChatGPT the asset and positive/negative prompt.
echo   3. Review the result at:
echo.
echo      http://127.0.0.1:8765/latest
echo.
echo The worker will also start automatically with Windows.
echo ===============================================
echo.
pause
exit /b 0

:gitfail
echo.
echo ERROR: Git update failed. No startup changes were made.
pause
exit /b 1
