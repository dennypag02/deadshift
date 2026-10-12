@echo off
setlocal
cd /d "%~dp0"

echo.
echo ========================================
echo   DeadShift Automated Asset Review
echo ========================================
echo.
echo ComfyUI Desktop must be open.
echo.

where git >nul 2>&1
if errorlevel 1 (
  echo ERROR: Git was not found in PATH.
  pause
  exit /b 1
)

where python >nul 2>&1
if errorlevel 1 (
  echo ERROR: Python was not found in PATH.
  pause
  exit /b 1
)

echo Updating the asset-pipeline branch...
git pull --ff-only
if errorlevel 1 (
  echo.
  echo Git pull could not complete automatically.
  echo Resolve the Git issue, then run this launcher again.
  pause
  exit /b 1
)

echo.
python asset_review_loop.py --asset car_suv --category cars --count 2
if errorlevel 1 (
  echo.
  echo The asset workflow stopped with an error.
  pause
  exit /b 1
)

echo.
echo Asset review session complete.
pause
