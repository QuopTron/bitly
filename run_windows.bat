@echo off
cd /d "%~dp0"
echo Building Go backend...
set PATH=C:\Program Files\Go\bin;%PATH%
cd go_backend_bitly
go build -o "..\bitly-backend.exe" .\cmd\server\
if %ERRORLEVEL% NEQ 0 (
    echo Go build failed!
    pause
    exit /b %ERRORLEVEL%
)
cd ..
echo Starting Flutter...
flutter run -d windows
