# Ejecutar: .\rebuild_all.ps1

Write-Host "=== REBUILD COMPLETO DE BITLY ===" -ForegroundColor Cyan

# Configurar ambiente
$ROOT = "e:\Pablo\proyectos\bitly"
$GO_DIR = "$ROOT\go_backend"
$ANDROID_SDK = "C:\Users\Carlos_M\AppData\Local\Android\Sdk"
$NDK = "$ANDROID_SDK\ndk\27.0.12077973"
$env:ANDROID_HOME = $ANDROID_SDK
$env:ANDROID_NDK_HOME = $NDK

# 1. Configurar ambiente Java
Write-Host "`n[1/8] Configurando ambiente Java..." -ForegroundColor Yellow
$env:JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"
$env:PATH="$env:JAVA_HOME\bin;$env:PATH"
Write-Host "Java configurado: $env:JAVA_HOME" -ForegroundColor Green

# 2. Build backend Go Windows
Write-Host "`n[2/8] Compilando backend Go para Windows..." -ForegroundColor Yellow
Set-Location $GO_DIR
go build -ldflags="-s -w" -o "$ROOT\windows\backend\bitly-backend.exe" ./cmd/server
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR: Build Windows Go fallido" -ForegroundColor Red; exit 1 }
Write-Host "Backend Windows compilado: windows\backend\bitly-backend.exe" -ForegroundColor Green

# 3. Build AAR Android
Write-Host "`n[3/8] Compilando AAR para Android..." -ForegroundColor Yellow
gomobile bind -target=android -androidapi=24 -o "$ROOT\android\app\libs\bitly.aar" .
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR: Build AAR fallido" -ForegroundColor Red; exit 1 }
Write-Host "AAR compilado: android\app\libs\bitly.aar" -ForegroundColor Green

# 4. Build iOS Framework
Write-Host "`n[4/8] Compilando framework para iOS..." -ForegroundColor Yellow
gomobile bind -target=ios -o "$ROOT\ios\Runner\Gobackend.xcframework" .
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR: Build iOS framework fallido" -ForegroundColor Red; exit 1 }
Write-Host "iOS framework compilado: ios\Runner\Gobackend.xcframework" -ForegroundColor Green

# 5. Build macOS Framework
Write-Host "`n[5/8] Compilando framework para macOS..." -ForegroundColor Yellow
gomobile bind -target=macos -o "$ROOT\macos\Runner\Gobackend.framework" .
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR: Build macOS framework fallido" -ForegroundColor Red }
Write-Host "macOS framework compilado: macos\Runner\Gobackend.framework" -ForegroundColor Green

# 6. Build Go server para Linux
Write-Host "`n[6/8] Compilando backend Go para Linux..." -ForegroundColor Yellow
$env:GOOS="linux"; $env:GOARCH="amd64"
go build -ldflags="-s -w" -o "$ROOT\linux\runner\bitly-backend" ./cmd/server
$env:GOOS=""; $env:GOARCH=""
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR: Build Linux Go fallido" -ForegroundColor Red }
Write-Host "Backend Linux compilado: linux\runner\bitly-backend" -ForegroundColor Green

# 7. Flutter pub get
Write-Host "`n[7/8] Instalando dependencias Flutter..." -ForegroundColor Yellow
Set-Location $ROOT
flutter pub get
if ($LASTEXITCODE -ne 0) { Write-Host "ERROR: flutter pub get fallido" -ForegroundColor Red; exit 1 }
Write-Host "Dependencias instaladas" -ForegroundColor Green

# 8. Verificar dispositivos
Write-Host "`n[8/8] Verificando dispositivos..." -ForegroundColor Yellow
$devices = flutter devices 2>&1 | Select-String "android"
if ($devices) {
    Write-Host "Dispositivo Android detectado" -ForegroundColor Green
    Write-Host "Ejecuta: flutter run -d <device-id>" -ForegroundColor Yellow
} else {
    Write-Host "No se detectó dispositivo Android" -ForegroundColor Red
}

Write-Host "`n=== BUILD COMPLETO EXITOSO ===" -ForegroundColor Cyan
