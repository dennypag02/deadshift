@echo off
setlocal
cd /d "%~dp0"

powershell -NoProfile -Command "$p = Get-CimInstance Win32_Process | Where-Object { $_.Name -match '^pythonw?\.exe$' -and $_.CommandLine -like '*local_worker.py*' }; if ($p) { $p | ForEach-Object { Stop-Process -Id $_.ProcessId -Force } }"
timeout /t 1 /nobreak >nul

for /f "delims=" %%P in ('python -c "import os,sys; print(os.path.join(os.path.dirname(sys.executable), ''pythonw.exe''))"') do set "PYTHONW=%%P"
if not exist "%PYTHONW%" set "PYTHONW=pythonw.exe"

start "" "%PYTHONW%" "%~dp0local_worker.py"
timeout /t 2 /nobreak >nul
start "" "http://127.0.0.1:8765/"
exit /b 0
