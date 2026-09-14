; ─────────────────────────────────────────────────────────────
; instalador_windows.iss — Instalador de Bitly para Windows
; usando Inno Setup. Empaqueta bitly.exe + bitly-backend.exe +
; data/ + todas las DLLs en un Setup.exe que instala en
; %LOCALAPPDATA%\Programs\Bitly y crea accesos directos.
;
; Uso:
;   ISCC.exe scripts/build/instalador_windows.iss
;   (o: "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" ...)
;
; OJO con las rutas relativas: este script vive en scripts/build/, así que para
; llegar a la raíz del repo hacen falta DOS niveles (..\..\). Con un solo ..\
; Inno resuelve dentro de scripts/ y el compilado falla con "El sistema no puede
; encontrar la ruta especificada" (lo que pasaba al mover el instalador desde
; scripts/ a scripts/build/).
;
; Parte del flujo: release de escritorio (Windows).
; ─────────────────────────────────────────────────────────────

#define MyAppName "Bitly"
; La versión se puede sobrescribir desde la línea de comandos con
;   ISCC.exe /DMyAppVersion=0.9.10 scripts/build/instalador_windows.iss
; así el CI la toma del pubspec y el asset queda como
; Bitly-Setup-<versión>.exe (nombre que leen la app y el sitio web).
#ifndef MyAppVersion
  #define MyAppVersion "0.9.9"
#endif
#define MyAppPublisher "Bitly"
#define MyAppExeName "bitly.exe"
#define MyAppBackendName "bitly-backend.exe"

; ── Arquitectura ────────────────────────────────────────────────────────────
; El build de Flutter sale en build\windows\<arch>\runner\Release, así que la
; carpeta NO se puede hardcodear a x64: las PCs nuevas (Snapdragon X, Surface
; Pro ARM) compilan x64 con emulación pero arm64 nativo. El script de build
; pasa /DMyBuildArch=arm64 cuando corresponde; por defecto x64.
#ifndef MyBuildArch
  #define MyBuildArch "x64"
#endif

; Sufijo del nombre del asset, derivado de la arquitectura. El de x64 se deja
; EXACTO (Bitly-Setup-<ver>.exe) porque así lo esperan el detector de versiones
; de la app y el sitio web; el de arm64 se distingue con -arm64 para que los dos
; assets puedan convivir en la misma GitHub Release.
#ifdef MyBuildArm64
  #define MyOutputSuffix "-arm64"
#else
  #define MyOutputSuffix ""
#endif

[Setup]
AppId={{8E3B9F2C-4A1D-4F6E-9C2B-B1A5C7D3E9F0}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
; Instala por usuario (sin UAC) — más simple y no requiere admin.
PrivilegesRequired=lowest
OutputDir=..\..\dist
OutputBaseFilename=Bitly-Setup-{#MyAppVersion}{#MyOutputSuffix}
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; `x64compatible` = x64 O arm64 (Windows ejecuta el paquete x64 por emulación
; en las máquinas ARM), y el paquete arm64 solo entra donde es nativo.
#ifdef MyBuildArm64
  ArchitecturesAllowed=arm64
  ArchitecturesInstallIn64BitMode=arm64
#else
  ArchitecturesAllowed=x64compatible
  ArchitecturesInstallIn64BitMode=x64compatible
#endif
UninstallDisplayIcon={app}\{#MyAppExeName}
; El backend y el exe principal corren juntos; la app los gestiona.
CloseApplications=yes
RestartApplications=no
; ── Wizard estándar ──
; El instalador pregunta IDIOMA (español/inglés) y CARPETA de
; instalación; la app adentro tiene su propio setup de idioma y de
; carpeta de descargas (cosas distintas al instalador).
DisableWelcomePage=no
DisableReadyPage=no

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Todos los archivos del build de release de Flutter Windows. El script de
; build (scripts/build/build_windows_release.sh) borra signed_sessions del Release
; ANTES de compilar, para que el instalador SIEMPRE salga limpio y cada
; instalación fuerce verificar las extensiones.
; La carpeta depende de la arquitectura ({#MyBuildArch}); hardcodear x64 dejaba
; el instalador arm64 apuntando a un build que no existe.
Source: "..\..\build\windows\{#MyBuildArch}\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Limpia datos de la app al desinstalar (sesiones firmadas, caché de
; extensiones). Las descargas de música NO se tocan (viven en la carpeta
; de descargas elegida por el usuario).
Type: filesandordirs; Name: "{userappdata}\bitly-music-app"
Type: filesandordirs; Name: "{userappdata}\bitly\extensions"