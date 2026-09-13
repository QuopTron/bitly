; ─────────────────────────────────────────────────────────────
; instalador_windows.iss — Instalador de Bitly para Windows
; usando Inno Setup. Empaqueta bitly.exe + bitly-backend.exe +
; data/ + todas las DLLs en un Setup.exe que instala en
; %LOCALAPPDATA%\Programs\Bitly y crea accesos directos.
;
; Uso:
;   ISCC.exe scripts/instalador_windows.iss
;   (o: "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" ...)
;
; Parte del flujo: release de escritorio (Windows).
; ─────────────────────────────────────────────────────────────

#define MyAppName "Bitly"
; La versión se puede sobrescribir desde la línea de comandos con
;   ISCC.exe /DMyAppVersion=0.9.10 scripts/instalador_windows.iss
; así el CI la toma del pubspec y el asset queda como
; Bitly-Setup-<versión>.exe (nombre que leen la app y el sitio web).
#ifndef MyAppVersion
  #define MyAppVersion "0.9.9"
#endif
#define MyAppPublisher "Bitly"
#define MyAppExeName "bitly.exe"
#define MyAppBackendName "bitly-backend.exe"

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
OutputDir=..\dist
OutputBaseFilename=Bitly-Setup-{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64compatible
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
; build (scripts/build_windows_release.sh) borra signed_sessions del Release
; ANTES de compilar, para que el instalador SIEMPRE salga limpio y cada
; instalación fuerce verificar las extensiones.
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

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