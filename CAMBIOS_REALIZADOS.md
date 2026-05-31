# Resumen de Cambios - Correcciones Android

## Problemas Solucionados

### 1. ✅ Selector de Carpetas SAF (Storage Access Framework)
**Problema**: El selector de carpetas no funcionaba en Android porque se intentaba llamar al backend Go, pero SAF debe manejarse nativamente desde Kotlin.

**Solución**:
- Implementado selector SAF nativo en `MainActivity.kt`
- Se usa `Intent.ACTION_OPEN_DOCUMENT_TREE` para abrir el picker nativo de Android
- Se persisten los permisos con `takePersistableUriPermission`
- Se obtiene el nombre de la carpeta seleccionada
- Se retorna el URI y nombre al código Flutter

**Archivos Modificados**:
- `android/app/src/main/kotlin/com/example/bitly/MainActivity.kt`
  - Agregado `pickSafTreeNative()` method
  - Agregado `onActivityResult()` para manejar el resultado
  - Agregado `getTreeDisplayName()` para obtener el nombre de la carpeta

### 2. ✅ Idioma Predeterminado Español
**Problema**: La app iniciaba en inglés en lugar de español en dispositivos Android.

**Solución**:
- Modificado `app.dart` para usar el locale desde settings en lugar de hardcodear
- Si el locale está vacío, usa español ('es') como predeterminado
- Si el locale es 'system', usa el idioma del sistema
- Soporta locales con formato 'es', 'en', 'zh_CN', etc.

**Archivos Modificados**:
- `lib/app.dart`
  - Ahora lee `settings.locale` del settingsProvider
  - Crea dinámicamente el objeto Locale basado en la configuración

### 3. ✅ Funciones Faltantes en AAR de Gomobile
**Problema**: Tres funciones requeridas por MainActivity.kt no estaban exportadas en el AAR.

**Solución**:
- Agregadas funciones wrapper en el código Go:
  - `GetPendingDownloadQueueRowsJSON()` - alias para `GetPendingDownloadQueueRows()`
  - `SetDownloadFallbackExtensionIdsJSON()` - alias para `SetExtensionFallbackProviderIDsJSON()`
  - `PickSafTree()` - stub que indica que debe manejarse nativamente

**Archivos Modificados**:
- `go_backend_spotiflac/database.go`
  - Agregada función `GetPendingDownloadQueueRowsJSON()`
- `go_backend_spotiflac/exports.go`
  - Agregada función `SetDownloadFallbackExtensionIdsJSON()`
  - Agregada función `PickSafTree()`

## Sobre las Extensiones

Las extensiones **ya están configuradas** para funcionar tanto en Android como en PC:

### Instalación de Extensiones:
1. **En Android**: 
   - Usa el store de extensiones integrado
   - Descarga desde el registry HTTPS
   - Instala en directorio de documentos de la app
   - No requiere permisos especiales

2. **En PC (Windows/Linux/Mac)**:
   - Usa el mismo sistema de store
   - Backend Go se ejecuta como proceso separado
   - Extensiones se instalan en el sistema de archivos local

### Funcionamiento:
- Las extensiones por defecto (deezer, amazon, ytmusic, etc.) se instalan automáticamente en el primer inicio
- El store de extensiones se inicializa con el directorio temporal como cache
- Las extensiones se instalan en `{appDir}/extensions`

## Comandos de Construcción

### Para reconstruir el AAR de Android:
```powershell
cd go_backend_spotiflac
$env:ANDROID_NDK_HOME="C:\Users\Carlos_M\AppData\Local\Android\Sdk\ndk\27.0.12077973"
$env:JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"
$env:PATH="$env:JAVA_HOME\bin;$env:PATH"
gomobile bind -v -target=android -androidapi 21 -o ..\android\app\libs\spotiflac.aar .
```

### Para construir la app Android:
```powershell
flutter build apk --debug
```

### Para ejecutar en dispositivo:
```powershell
flutter run
```

## Pruebas Recomendadas

1. **Selector SAF**:
   - Ir a Ajustes > Archivos > Ubicación de descargas
   - Tocar "Seleccionar carpeta"
   - Debería abrirse el picker nativo de Android
   - Seleccionar una carpeta y verificar que se guarda

2. **Idioma**:
   - Instalar la app en un dispositivo
   - Verificar que inicia en español
   - Ir a Ajustes > Apariencia > Idioma
   - Cambiar a otro idioma y verificar que funciona

3. **Extensiones**:
   - Ir a la pestaña Repositorio
   - Verificar que se cargan las extensiones disponibles
   - Intentar instalar una extensión
   - Verificar que aparece en Ajustes > Extensiones

## Notas Importantes

- El selector SAF solo funciona en Android 5.0+ (API 21+)
- En Android 13+, se recomienda usar SAF en lugar de MANAGE_EXTERNAL_STORAGE
- Los permisos SAF se persisten entre reinicios del dispositivo
- El idioma predeterminado es español para todos los usuarios nuevos
