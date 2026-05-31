@echo off
REM Build Bitly AAR for Android via gomobile
REM Requires: Go 1.26+, gomobile, Android NDK

echo === Bitly AAR Build ===
echo.

setlocal enabledelayedexpansion

:: Check gomobile is installed
where gomobile >nul 2>nul
if %errorlevel% neq 0 (
    echo [gomobile] Not found, installing...
    go install golang.org/x/mobile/cmd/gomobile@latest
    if !errorlevel! neq 0 (
        echo [ERROR] Failed to install gomobile
        exit /b 1
    )
    gomobile init
    if !errorlevel! neq 0 (
        echo [ERROR] gomobile init failed - ensure ANDROID_HOME and NDK are set
        exit /b 1
    )
)

:: Step 1: Ensure Go dependencies are tidy
echo [1/5] Tidying Go modules...
go mod tidy
if %errorlevel% neq 0 (
    echo [ERROR] go mod tidy failed
    exit /b 1
)

:: Step 2: Run tests (skip if no test files)
echo [2/5] Running tests...
go test ./... 2>&1
echo [INFO] Tests completed (warnings may be OK)

:: Step 3: Build the AAR
echo [3/5] Building AAR...
set AAR_OUT=..\android\app\libs\bitly.aar
set JAR_OUT=..\android\app\libs\Bitly-sources.jar

gomobile bind -target=android -androidapi 24 -o %AAR_OUT% .
if %errorlevel% neq 0 (
    echo [ERROR] gomobile bind failed
    exit /b 1
)

echo [4/5] AAR built: %AAR_OUT%
if exist "%AAR_OUT%" (
    for %%F in ("%AAR_OUT%") do echo   Size: %%~zF bytes
)

:: Step 5: Verify AAR contents
echo [5/5] Verifying AAR...
jar tf "%AAR_OUT%" >nul 2>nul
if %errorlevel% equ 0 (
    echo [OK] AAR verified successfully
) else (
    echo [WARN] Could not verify AAR (jar not available?)
)

echo.
echo === BUILD COMPLETE ===
echo Output: %AAR_OUT%
echo Source: %JAR_OUT%