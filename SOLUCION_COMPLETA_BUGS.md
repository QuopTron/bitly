# 🔧 Solución Completa para Bugs en BitLy

## ❌ Problemas Identificados

### 1. **YT-DLP no funciona en Android**
- ❌ Race condition: se intenta usar antes de descargar
- ❌ No tiene permisos de ejecución
- ❌ Python no existe en Android (yt-dlp lo requiere)
- ✅ El fallback de Go SÍ funciona

### 2. **SQLite: Tablas no existen**
- ❌ `InitMasterDatabase()` NO crea tablas
- ❌ 14 tablas faltantes (application_state, files, metadata, etc.)
- ❌ Configuración no persiste
- ❌ Historial/Favoritos no funcionan

### 3. **Extensiones fallan al descargar**
- ❌ Intenta escribir en `/data/local/tmp` (sin permisos en Android)
- ❌ Flutter usa `/data/user/0/.../cache` pero Go usa `/data/local/tmp`
- ✅ Después sí descarga correctamente desde Flutter

### 4. **Música no reproduce**
- ❌ Extensiones no pueden resolver URLs (Apple Music, etc.)
- ❌ Tablas de descargas no existen (por SQLite)
- ❌ Métodos parecen no implementados (pero es por las tablas)

---

## ✅ SOLUCIONES - Orden de Implementación

### PASO 1: Corregir SQLite (CRÍTICO) ⚠️

**Archivo:** `go_backend_spotiflac/database.go`

**Agregar después de línea 41:**

```go
// ensureDatabaseSchema creates all necessary tables and indexes
func ensureDatabaseSchema(db *sql.DB) error {
	schema := `
-- Application settings
CREATE TABLE IF NOT EXISTS application_state (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
);

-- Downloaded files registry
CREATE TABLE IF NOT EXISTS files (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    path TEXT NOT NULL UNIQUE,
    file_type TEXT,
    size_bytes INTEGER,
    created_at INTEGER,
    last_accessed INTEGER
);

-- Music metadata (albums, tracks, artists)
CREATE TABLE IF NOT EXISTS metadata (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT NOT NULL, -- 'album', 'track', 'artist', 'playlist'
    external_id TEXT,
    title TEXT,
    artist TEXT,
    album TEXT,
    isrc TEXT,
    spotify_id TEXT,
    duration_ms INTEGER,
    release_date TEXT,
    cover_url TEXT,
    data_json TEXT, -- full JSON payload
    source TEXT, -- 'deezer', 'tidal', 'qobuz', etc.
    created_at INTEGER,
    updated_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_metadata_type ON metadata(type);
CREATE INDEX IF NOT EXISTS idx_metadata_spotify_id ON metadata(spotify_id);
CREATE INDEX IF NOT EXISTS idx_metadata_isrc ON metadata(isrc);
CREATE INDEX IF NOT EXISTS idx_metadata_title_artist ON metadata(title, artist);

-- Download queue
CREATE TABLE IF NOT EXISTS download_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    track_id TEXT NOT NULL,
    track_title TEXT,
    artist_name TEXT,
    album_name TEXT,
    extension_id TEXT,
    status TEXT DEFAULT 'pending', -- 'pending', 'downloading', 'completed', 'failed'
    progress REAL DEFAULT 0.0,
    error_message TEXT,
    file_path TEXT,
    added_at INTEGER,
    completed_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_download_queue_status ON download_queue(status);

-- Collections (playlists, favorites, wishlists)
CREATE TABLE IF NOT EXISTS collections (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    type TEXT NOT NULL, -- 'playlist', 'wishlist', 'loved'
    description TEXT,
    cover_url TEXT,
    item_count INTEGER DEFAULT 0,
    created_at INTEGER,
    updated_at INTEGER
);

CREATE INDEX IF NOT EXISTS idx_collections_type ON collections(type);

-- Collection items (tracks in playlists, etc.)
CREATE TABLE IF NOT EXISTS collection_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    collection_id INTEGER NOT NULL,
    metadata_id INTEGER NOT NULL,
    position INTEGER,
    added_at INTEGER,
    FOREIGN KEY (collection_id) REFERENCES collections(id) ON DELETE CASCADE,
    FOREIGN KEY (metadata_id) REFERENCES metadata(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_collection_items_collection ON collection_items(collection_id);
CREATE INDEX IF NOT EXISTS idx_collection_items_metadata ON collection_items(metadata_id);

-- Recent access history
CREATE TABLE IF NOT EXISTS recent_access (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    metadata_id INTEGER NOT NULL,
    access_type TEXT, -- 'play', 'download', 'view'
    accessed_at INTEGER,
    FOREIGN KEY (metadata_id) REFERENCES metadata(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_recent_access_timestamp ON recent_access(accessed_at DESC);

-- Hidden downloads (for UI filtering)
CREATE TABLE IF NOT EXISTS hidden_download_ids (
    id TEXT PRIMARY KEY
);

-- Extension configuration
CREATE TABLE IF NOT EXISTS extension_config (
    extension_id TEXT PRIMARY KEY,
    enabled INTEGER DEFAULT 1,
    config_json TEXT,
    last_updated INTEGER
);

-- Playback history
CREATE TABLE IF NOT EXISTS playback_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    track_id TEXT NOT NULL,
    track_title TEXT,
    artist_name TEXT,
    played_at INTEGER,
    duration_played_ms INTEGER
);

CREATE INDEX IF NOT EXISTS idx_playback_history_timestamp ON playback_history(played_at DESC);

-- ISRC cache for track matching
CREATE TABLE IF NOT EXISTS isrc_cache (
    isrc TEXT PRIMARY KEY,
    track_id TEXT,
    metadata_json TEXT,
    cached_at INTEGER
);

-- Cover cache metadata
CREATE TABLE IF NOT EXISTS cover_cache (
    url TEXT PRIMARY KEY,
    local_path TEXT,
    cached_at INTEGER,
    size_bytes INTEGER
);

-- Statistics
CREATE TABLE IF NOT EXISTS statistics (
    key TEXT PRIMARY KEY,
    value INTEGER DEFAULT 0
);
`

	// Execute schema creation
	_, err := db.Exec(schema)
	if err != nil {
		return fmt.Errorf("failed to create schema: %w", err)
	}

	// Enable foreign keys
	_, err = db.Exec("PRAGMA foreign_keys = ON;")
	if err != nil {
		return fmt.Errorf("failed to enable foreign keys: %w", err)
	}

	log.Println("[Database] Schema initialized successfully")
	return nil
}
```

**Modificar función `InitMasterDatabase()` (línea 42-60):**

```go
// InitMasterDatabase initializes the master SQLite database
// This is where the file index, metadata cache, download queue, etc. are stored.
func InitMasterDatabase(dbPath string) error {
	var err error
	masterDB, err = sql.Open("sqlite3", dbPath)
	if err != nil {
		return fmt.Errorf("failed to open master database: %w", err)
	}

	// Test connection
	if err := masterDB.Ping(); err != nil {
		return fmt.Errorf("failed to ping database: %w", err)
	}

	// ✅ AGREGAR ESTA LÍNEA:
	if err := ensureDatabaseSchema(masterDB); err != nil {
		return fmt.Errorf("failed to initialize schema: %w", err)
	}

	log.Println("Master database initialized successfully")
	return nil
}
```

---

### PASO 2: Corregir yt-dlp en Android

**Archivo:** `android/app/src/main/kotlin/com/example/bitly/YouTubeService.kt`

**Reemplazar toda la función `searchYouTubeVideo()`:**

```kotlin
fun searchYouTubeVideo(trackName: String, artistName: String): String? {
    return try {
        // Usar directamente Go backend (ya maneja yt-dlp internamente)
        val goResult = Gobackend.searchYouTubeVideo(trackName, artistName)
        
        if (goResult.isNullOrEmpty()) {
            Log.i(TAG, "No video found for: $trackName - $artistName")
            null
        } else {
            Log.i(TAG, "Found video: $goResult")
            goResult
        }
    } catch (e: Exception) {
        Log.e(TAG, "YouTube search failed", e)
        null
    }
}
```

**Archivo:** `go_backend_spotiflac/ytdlp_installer.go`

**Reemplazar función `EnsureYtDlp()` (línea 54-96):**

```go
func EnsureYtDlp() error {
	path := GetYtDlpPath()

	// Verificar si ya existe y tiene permisos correctos
	if info, err := os.Stat(path); err == nil {
		// En sistemas Unix, verificar permisos de ejecución
		if runtime.GOOS != "windows" {
			if info.Mode()&0111 != 0 {
				return nil // Ya existe y es ejecutable
			}
		} else {
			return nil // En Windows, asumimos que está bien
		}
	}

	// Construir URL de descarga
	url := "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp"
	if runtime.GOOS == "windows" {
		url += ".exe"
	}

	fmt.Printf("[YouTube] Downloading yt-dlp from %s...\n", url)

	// Descargar
	resp, err := http.Get(url)
	if err != nil {
		return fmt.Errorf("failed to download yt-dlp: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("download failed with status: %d", resp.StatusCode)
	}

	// Crear archivo temporal
	tmpPath := path + ".tmp"
	out, err := os.Create(tmpPath)
	if err != nil {
		return fmt.Errorf("failed to create temp file %s: %w", tmpPath, err)
	}

	// Copiar contenido
	_, copyErr := io.Copy(out, resp.Body)
	out.Close() // Cerrar antes de verificar error

	if copyErr != nil {
		os.Remove(tmpPath) // Limpiar
		return fmt.Errorf("failed to save yt-dlp: %w", copyErr)
	}

	// Dar permisos de ejecución ANTES de mover
	if runtime.GOOS != "windows" {
		if err := os.Chmod(tmpPath, 0755); err != nil {
			os.Remove(tmpPath)
			return fmt.Errorf("failed to chmod yt-dlp (permissions denied on Android): %w", err)
		}
	}

	// Mover atómicamente al destino final
	if err := os.Rename(tmpPath, path); err != nil {
		os.Remove(tmpPath)
		return fmt.Errorf("failed to move yt-dlp to final location: %w", err)
	}

	fmt.Println("[YouTube] yt-dlp installed successfully at:", path)
	return nil
}
```

---

### PASO 3: Corregir rutas de extensiones en Android

**Archivo:** `go_backend_spotiflac/extension_store.go`

Buscar la función `downloadStoreExtensionJSON` (alrededor de línea 200-250).

**Modificar para usar ruta correcta:**

```go
func (s *ExtensionStore) downloadStoreExtensionJSON(ext StoreExtension, outputDir string) (string, error) {
	// Asegurar que el directorio existe
	if err := os.MkdirAll(outputDir, 0755); err != nil {
		return "", fmt.Errorf("failed to create output directory: %w", err)
	}

	filename := ext.ID + ".spotiflac-ext"
	fullPath := filepath.Join(outputDir, filename)

	// Descargar a archivo temporal
	tempPath := fullPath + ".part"
	
	// ✅ AGREGAR LOG para debug:
	fmt.Printf("[ExtensionStore] Downloading %s to %s\n", ext.Name, tempPath)

	// Descargar
	resp, err := http.Get(ext.URL)
	if err != nil {
		return "", fmt.Errorf("failed to download extension: %w", err)
	}
	defer resp.Body.Close()

	// Crear archivo temporal
	out, err := os.Create(tempPath)
	if err != nil {
		// ✅ ERROR MEJORADO con permisos:
		return "", fmt.Errorf("failed to create file: %w (dir: %s, has permissions: %v)", 
			err, outputDir, hasWritePermissions(outputDir))
	}

	_, copyErr := io.Copy(out, resp.Body)
	out.Close()

	if copyErr != nil {
		os.Remove(tempPath)
		return "", fmt.Errorf("failed to save extension: %w", copyErr)
	}

	// Mover a ubicación final
	if err := os.Rename(tempPath, fullPath); err != nil {
		os.Remove(tempPath)
		return "", fmt.Errorf("failed to finalize extension file: %w", err)
	}

	fmt.Printf("[ExtensionStore] Downloaded to=%s\n", fullPath)
	return fullPath, nil
}

// Helper para verificar permisos
func hasWritePermissions(dir string) bool {
	testFile := filepath.Join(dir, ".write_test")
	f, err := os.Create(testFile)
	if err != nil {
		return false
	}
	f.Close()
	os.Remove(testFile)
	return true
}
```

**Archivo:** `lib/main.dart` o archivo principal de Flutter

Asegurarse que al llamar bootstrap de extensiones, use la ruta correcta:

```dart
// En Flutter, al inicializar extensiones:
Future<void> initExtensions() async {
  final cacheDir = await getApplicationCacheDirectory(); // ✅ Correcto
  final extensionCachePath = '${cacheDir.path}/bootstrap_extensions';
  
  // NO usar /data/local/tmp - Android no permite escritura ahí desde apps
  await platformChannel.invokeMethod('bootstrapExtensions', {
    'cachePath': extensionCachePath, // ✅ Pasar a Go
  });
}
```

---

### PASO 4: Configurar permisos en AndroidManifest.xml

**Archivo:** `android/app/src/main/AndroidManifest.xml`

Asegurar que tiene estos permisos:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Permisos necesarios -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android:name="android.permission.WRITE_EXTERNAL_STORAGE" 
                     android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" 
                     android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"
                     tools:ignore="ScopedStorage" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
    
    <application
        android:name=".Application"
        android:label="BitLy"
        android:icon="@mipmap/ic_launcher"
        android:requestLegacyExternalStorage="true"
        android:usesCleartextTraffic="true">
        
        <!-- ... -->
    </application>
</manifest>
```

---

## 🧪 Testing y Validación

### Test 1: Verificar SQLite

Después de implementar PASO 1, ejecutar:

```bash
cd E:\Pablo\proyectos\bitly\go_backend_spotiflac
go build
./backend.exe  # O ./backend en Linux
```

Debería ver en logs:
```
[Database] Schema initialized successfully
Master database initialized successfully
```

### Test 2: Verificar Flutter + Go

```bash
flutter clean
flutter pub get
cd go_backend_spotiflac
go build -buildmode=c-archive -o libgobackend.a
flutter run -d windows
```

Buscar en logs:
- ❌ NO debería ver: `no such table: application_state`
- ✅ Debería ver: `Schema initialized successfully`

### Test 3: Verificar Android

```bash
flutter run -d emulator-5554
```

Buscar en logcat:
- ❌ NO debería ver: `failed to create file: /data/local/tmp`
- ✅ Debería ver: `Downloaded to=/data/user/0/.../cache/bootstrap_xxx`
- ✅ Debería ver: `Go master DB init requested`

---

## 📋 Checklist de Implementación

- [ ] PASO 1: Agregar `ensureDatabaseSchema()` en `database.go`
- [ ] PASO 1: Modificar `InitMasterDatabase()` para llamar al schema
- [ ] PASO 1: Compilar y probar backend standalone
- [ ] PASO 2: Simplificar `YouTubeService.kt` (eliminar ejecución directa)
- [ ] PASO 2: Mejorar `ytdlp_installer.go` con manejo de errores
- [ ] PASO 3: Corregir `extension_store.go` con rutas Android-safe
- [ ] PASO 3: Actualizar Flutter para pasar ruta correcta de cache
- [ ] PASO 4: Verificar permisos en `AndroidManifest.xml`
- [ ] Test en Windows
- [ ] Test en Android
- [ ] Verificar reproducción de música
- [ ] Verificar descarga de extensiones

---

## 🎯 Resultado Esperado

Después de implementar todos los pasos:

### ✅ LO QUE DEBERÍA FUNCIONAR:

1. **SQLite**: Todas las tablas creadas, configuración persiste
2. **YouTube**: Búsqueda funciona desde Go sin problemas de permisos
3. **Extensiones**: Descargan correctamente a `/data/user/0/.../cache`
4. **Reproducción**: Música reproduce correctamente
5. **Descargas**: Sistema de downloads funciona
6. **Historial/Favoritos**: Se guardan correctamente
7. **Windows + Android**: Funcionan ambas plataformas

### ⚠️ SI AÚN FALLA:

Si después de implementar PASO 1-4 aún hay problemas:

1. Compartir nuevos logs completos
2. Verificar que se recompiló el backend de Go
3. Verificar que Flutter detecta la nueva versión del backend
4. Limpiar cache: `flutter clean && flutter pub get`

---

## 📞 Próximos Pasos

1. Implementar PASO 1 (SQLite - más crítico)
2. Probar en Windows
3. Implementar PASO 2-3 (Android)
4. Probar en Android
5. Implementar PASO 4 (permisos)
6. Testing final

¿Por dónde empezamos?
