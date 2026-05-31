package main rebuild script with updated AAR
# Ejecutar: .\rebuild_all.ps1

Write-Host "=== REBUILD COMPLETO DE BITLY ===" -ForegroundColor Cyan

# 1. Configurar ambiente Java
Write-Host "`n[1/6] Configurando ambiente Java..." -ForegroundColor Yellow
$env:JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"
$env:PATH="$env:JAVA_HOME\bin;$env:PATH"
Write-Host "Java configurado: $env:JAVA_HOME" -ForegroundColor Green

# 2. Build backend Go
Write-Host "`n[2/6] Compilando backend Go..." -ForegroundColor Yellow
Set-Location "e:\Pablo\proyectos\bitly\go_backend_bitly"
go build -o "..\bitly-backend.exe" ./cmd/server
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Build Go fallido" -ForegroundColor Red
    exit 1
}
Write-Host "Backend Go compilado exitosamente" -ForegroundColor Green

# 3. Build AAR Android
Write-Host "`n[3/6] Compilando AAR para Android..." -ForegroundColor Yellow
gomobile bind -target=android -androidapi=24 -o ..\android\app\libs\Bitly.aar .
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Build AAR fallido" -ForegroundColor Red
    exit 1
}
Write-Host "AAR compilado exitosamente" -ForegroundColor Green

# 4. Flutter clean
Write-Host "`n[4/6] Limpiando Flutter..." -ForegroundColor Yellow
Set-Location "e:\Pablo\proyectos\bitly"
flutter clean
Write-Host "Flutter limpio" -ForegroundColor Green

# 5. Flutter pub get
Write-Host "`n[5/6] Instalando dependencias Flutter..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: flutter pub get fallido" -ForegroundColor Red
    exit 1
}
Write-Host "Dependencias instaladas" -ForegroundColor Green

# 6. Desinstalar app vieja
Write-Host "`n[6/6] Verificando dispositivos..." -ForegroundColor Yellow
$devices = flutter devices 2>&1 | Select-String "android-arm64"
if ($devices) {
    Write-Host "Dispositivo Android detectado" -ForegroundColor Green
    Write-Host "`n=== TODO LISTO ===" -ForegroundColor Cyan
    Write-Host "Ejecuta: flutter run -d <device-id>" -ForegroundColor Yellow
} else {
    Write-Host "`nNo se detectó dispositivo Android" -ForegroundColor Red
    Write-Host "Conecta tu teléfono y ejecuta: flutter run" -ForegroundColor Yellow
}

Write-Host "`n=== BUILD COMPLETO EXITOSO ===" -ForegroundColor Cyan
Write-Host "El AAR nuevo está en: android\app\libs\Bitly.aar" -ForegroundColor Green
