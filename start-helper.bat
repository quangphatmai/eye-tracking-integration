@echo off
title Eye Tracking Helper

rem ---- Settings: change these lines on a new computer ----
set "VENV=C:\pyenvs\eye-tracking-integration\venv"
rem The site is served from this computer at http://127.0.0.1:PORT/index.html (the same address as Live Server, so saved studies stay)
set "WEB_PORT=5500"
rem Optional: the address of a hosted site (Netlify / Vercel). When this is filled in, the local web server is not started
rem and this address is opened instead. Write only the address (no page name, no / at the end).
set "SITE_URL="
rem ---------------------------------------------------------

rem This file sits in the eye-tracking-integration folder. The helper is in .\bridge, the site is in ..\eye-tracking-app
set "BRIDGE=%~dp0bridge"
for %%I in ("%~dp0..\eye-tracking-app") do set "APP=%%~fI"

if not exist "%VENV%\Scripts\activate.bat" (
  echo Cannot find the Python environment: %VENV%
  echo Open start-helper.bat in Notepad and fix the VENV line.
  pause
  exit /b 1
)
if not exist "%BRIDGE%\bridge_server.py" (
  echo Cannot find bridge_server.py in: %BRIDGE%
  echo Keep start-helper.bat in the eye-tracking-integration folder.
  pause
  exit /b 1
)

call "%VENV%\Scripts\activate.bat"

if defined SITE_URL (
  set "OPEN_URL=%SITE_URL%"
  set "ORIGIN_ARGS=--origin %SITE_URL%"
) else (
  set "OPEN_URL=http://127.0.0.1:%WEB_PORT%/index.html"
  set "ORIGIN_ARGS="
  if exist "%APP%\index.html" (
    rem The site's own small web server, in a minimized window. It is closed again when the helper stops.
    start "Eye Tracking Web" /min cmd /c python -m http.server %WEB_PORT% --bind 127.0.0.1 --directory "%APP%"
  ) else (
    echo Cannot find the site folder: %APP%
    echo Keep eye-tracking-app next to eye-tracking-integration. Only the helper is started.
    set "OPEN_URL="
  )
)

rem Open the site in Chrome a few seconds from now, so the helper is already listening.
rem (If Chrome cannot be found, the default browser opens it instead.)
if defined OPEN_URL (
  start "" powershell -WindowStyle Hidden -Command "Start-Sleep 4; try { Start-Process chrome '%OPEN_URL%' -ErrorAction Stop } catch { Start-Process '%OPEN_URL%' }"
)

cd /d "%BRIDGE%"
python bridge_server.py --mode tobii %ORIGIN_ARGS% %*

rem The helper stopped: stop the site's web server too
taskkill /f /t /fi "WINDOWTITLE eq Eye Tracking Web*" >nul 2>&1

echo.
echo Helper stopped. Press any key to close this window.
pause >nul
