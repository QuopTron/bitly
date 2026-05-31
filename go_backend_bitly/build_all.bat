@echo off
REM Build Bitly para todas las plataformas
REM Requiere: Go 1.25+

echo === Bitly Multi-Platform Build ===
echo.

set GONOSUMCHECK=*
REM CGO required for ncruces/go-sqlite3 driver
set CGO_ENABLED=1

:: Windows
echo [1/4] Windows...
go build -o "..\bitly-backend.exe" .\cmd\server\ 2>&1
if %errorlevel% equ 0 (echo   OK: bitly-backend.exe) else (echo   ERROR)

:: Linux
echo [2/4] Linux...
set GOOS=linux
set GOARCH=amd64
go build -o "..\bitly-backend-linux" .\cmd\server\ 2>&1
if %errorlevel% equ 0 (echo   OK: bitly-backend-linux) else (echo   ERROR)

:: macOS Intel
echo [3/4] macOS...
set GOOS=darwin
set GOARCH=amd64
go build -o "..\bitly-backend-macos" .\cmd\server\ 2>&1
if %errorlevel% equ 0 (echo   OK: bitly-backend-macos) else (echo   ERROR)

:: macOS ARM
echo [4/4] macOS ARM...
set GOOS=darwin
set GOARCH=arm64
go build -o "..\bitly-backend-macos-arm64" .\cmd\server\ 2>&1
if %errorlevel% equ 0 (echo   OK: bitly-backend-macos-arm64) else (echo   ERROR)

echo.
echo === COMPLETADO ===
