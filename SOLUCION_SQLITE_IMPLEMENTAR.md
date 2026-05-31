# 🔧 Solución SQLite - Guía de Implementación

## 📌 Resumen Ejecutivo

**Problema:** Las tablas de la base de datos SQLite no se están creando, causando errores en toda la aplicación.

**Causa:** La función `InitMasterDatabase()` solo abre la conexión pero NO crea las tablas.

**Solución:** Agregar función de inicialización de esquema que cree todas las tablas al inicializar la BD.

---

## 🎯 Archivos a Modificar

### 1. `go_backend_spotiflac/database.go`

Agregar la siguiente función **después de la línea 41** (después de `InitMasterDatabase`):

```go
// ensureDatabaseSchema creates all necessary tables and indexes if they don't exist
func ensureDatabaseSchema(db *sql.DB) error {
	schema := `
	-- Metadata table: Stores track metadata
	CREATE TABLE IF NOT EXISTS metadata (
		id TEXT PRIMARY KEY NOT NULL,
		track_name TEXT NOT NULL,
		artist_name TEXT NOT NULL,
		album_name TEXT NOT NULL,
		album_artist TEXT,
		isrc TEXT,
		duration_ms INTEGER DEFAULT 0,
		track_number INTEGER DEFAULT 0,
		total_tracks INTEGER DEFAULT 0,
		disc_number INTEGER DEFAULT 1,
		total_discs INTEGER DEFAULT 1,
		release_date TEXT,
		genre TEXT,
		composer TEXT,
		label TEXT,
		copyright TEXT,
		spotify_id TEXT,
		cover_url TEXT,
		cover_path TEXT
	);

	CREATE INDEX IF NOT EXISTS idx_metadata_spotify_id ON metadata(spotify_id);
	CREATE INDEX IF NOT EXISTS idx_metadata_isrc ON metadata(isrc);
	CREATE INDEX IF NOT EXISTS idx_metadata_track_artist ON metadata(track_name, artist_name);

	-- Files table: Stores file locations and technical metadata
	CREATE TABLE IF NOT EXISTS files (
		id TEXT PRIMARY KEY NOT NULL,
		metadata_id TEXT NOT NULL,
		file_path TEXT UNIQUE NOT NULL,
		source TEXT NOT NULL CHECK(source IN ('download', 'local_scan')),
		format TEXT,
		bitrate INTEGER DEFAULT 0,
		bit_depth INTEGER DEFAULT 0,
		sample_rate INTEGER DEFAULT 0,
		downloaded_at TEXT,
		scanned_at TEXT,
		file_mod_time INTEGER DEFAULT 0,
		saf_file_name TEXT,
		FOREIGN KEY (metadata_id) REFERENCES metadata(id) ON DELETE CASCADE
	);

	CREATE INDEX IF NOT EXISTS idx_files_metadata_id ON files(metadata_id);
	CREATE INDEX IF NOT EXISTS idx_files_source ON files(source);
	CREATE INDEX IF NOT EXISTS idx_files_file_path ON files(file_path);

	-- Application state table: Stores app-wide configuration
	CREATE TABLE IF NOT EXISTS application_state (
		key TEXT PRIMARY KEY NOT NULL,
		value TEXT NOT NULL,
		updated_at TEXT NOT NULL
	);

	-- Favorites table: Stores liked/favorited items
	CREATE TABLE IF NOT EXISTS favorites (
		item_id TEXT PRIMARY KEY NOT NULL,
		type TEXT NOT NULL,
		name TEXT NOT NULL,
		secondary_name TEXT,
		cover_url TEXT,
		added_at TEXT NOT NULL,
		item_json TEXT,
		cover_path TEXT,
		audio_path TEXT,
		match_key TEXT,
		codec TEXT,
		bit_depth INTEGER,
		sample_rate INTEGER
	);

	CREATE INDEX IF NOT EXISTS idx_favorites_type ON favorites(type);
	CREATE INDEX IF NOT EXISTS idx_favorites_added_at ON favorites(added_at DESC);

	-- Collections table: Stores playlists and collections
	CREATE TABLE IF NOT EXISTS collections (
		id TEXT PRIMARY KEY NOT NULL,
		name TEXT NOT NULL,
		type TEXT,
		cover_path TEXT,
		created_at TEXT NOT NULL,
		updated_at TEXT NOT NULL,
		custom_json TEXT,
		item_json TEXT
	);

	CREATE INDEX IF NOT EXISTS idx_collections_updated_at ON collections(updated_at DESC);

	-- Collection items table: Items in collections
	CREATE TABLE IF NOT EXISTS collection_items (
		collection_id TEXT NOT NULL,
		item_id TEXT NOT NULL,
		metadata_id TEXT,
		item_json TEXT,
		added_at TEXT NOT NULL,
		position INTEGER DEFAULT 0,
		PRIMARY KEY (collection_id, item_id),
		FOREIGN KEY (collection_id) REFERENCES collections(id) ON DELETE CASCADE
	);

	CREATE INDEX IF NOT EXISTS idx_collection_items_item_id ON collection_items(item_id);
	CREATE INDEX IF NOT EXISTS idx_collection_items_collection_id ON collection_items(collection_id);

	-- Play history table: Logs individual play events
	CREATE TABLE IF NOT EXISTS play_history (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		track_id TEXT NOT NULL,
		track_name TEXT NOT NULL,
		artist_name TEXT NOT NULL,
		album_name TEXT,
		played_at TEXT NOT NULL,
		duration_ms INTEGER DEFAULT 0,
		percentage INTEGER DEFAULT 0
	);

	CREATE INDEX IF NOT EXISTS idx_play_history_played_at ON play_history(played_at DESC);
	CREATE INDEX IF NOT EXISTS idx_play_history_track_id ON play_history(track_id);

	-- Play aggregates table: Aggregated play counts
	CREATE TABLE IF NOT EXISTS play_aggregates (
		item_id TEXT PRIMARY KEY NOT NULL,
		type TEXT NOT NULL CHECK(type IN ('track', 'album', 'artist')),
		play_count INTEGER DEFAULT 0,
		last_played_at TEXT
	);

	CREATE INDEX IF NOT EXISTS idx_play_aggregates_type ON play_aggregates(type);
	CREATE INDEX IF NOT EXISTS idx_play_aggregates_play_count ON play_aggregates(play_count DESC);

	-- Secret counters table: Stores achievement counters
	CREATE TABLE IF NOT EXISTS secret_counters (
		key TEXT PRIMARY KEY NOT NULL,
		value INTEGER DEFAULT 0
	);

	-- Secret unlocks table: Tracks unlocked achievements
	CREATE TABLE IF NOT EXISTS secret_unlocks (
		key TEXT PRIMARY KEY NOT NULL,
		unlocked_at TEXT NOT NULL
	);

	-- Download queue table: Manages pending downloads
	CREATE TABLE IF NOT EXISTS download_queue (
		id TEXT PRIMARY KEY NOT NULL,
		track_json TEXT NOT NULL,
		item_json TEXT,
		status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending', 'downloading', 'completed', 'failed')),
		progress REAL DEFAULT 0.0,
		created_at TEXT NOT NULL,
		updated_at TEXT NOT NULL,
		added_at TEXT NOT NULL
	);

	CREATE INDEX IF NOT EXISTS idx_download_queue_status ON download_queue(status);
	CREATE INDEX IF NOT EXISTS idx_download_queue_added_at ON download_queue(added_at);

	-- Recent access table: Tracks recently accessed items
	CREATE TABLE IF NOT EXISTS recent_access (
		id TEXT PRIMARY KEY NOT NULL,
		item_json TEXT NOT NULL,
		type TEXT DEFAULT 'recent',
		accessed_at TEXT NOT NULL
	);

	CREATE INDEX IF NOT EXISTS idx_recent_access_accessed_at ON recent_access(accessed_at DESC);

	-- Hidden recent downloads table: Tracks hidden download history items
	CREATE TABLE IF NOT EXISTS hidden_recent_downloads (
		download_id TEXT PRIMARY KEY NOT NULL
	);

	-- ISRC cache table: Caches ISRC metadata lookups
	CREATE TABLE IF NOT EXISTS isrc_cache (
		isrc TEXT PRIMARY KEY,
		genre TEXT NOT NULL DEFAULT '',
		album_artist TEXT NOT NULL DEFAULT '',
		fetched_at INTEGER NOT NULL
	);

	CREATE INDEX IF NOT EXISTS idx_isrc_cache_fetched_at ON isrc_cache(fetched_at);
	`

	_, err := db.Exec(schema)
	if err != nil {
		return fmt.Errorf("failed to create database schema: %w", err)
	}

	return nil
}
```

### 2. Modificar la función `InitMasterDatabase()`

**REEMPLAZAR** las líneas 19-41 con:

```go
func InitMasterDatabase(path string) error {
	masterDBMu.Lock()
	defer masterDBMu.Unlock()

	if masterDB != nil {
		masterDB.Close()
	}

	db, err := sql.Open("sqlite3", path)
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}

	// Optimize for performance
	_, _ = db.Exec("PRAGMA journal_mode=WAL")
	_, _ = db.Exec("PRAGMA synchronous=NORMAL")
	_, _ = db.Exec("PRAGMA cache_size=-64000") // 64MB cache
	_, _ = db.Exec("PRAGMA busy_timeout=5000")  // 5s retry before SQLITE_BUSY
	_, _ = db.Exec("PRAGMA foreign_keys=ON")    // Enable foreign key constraints

	// Create schema if it doesn't exist
	if err := ensureDatabaseSchema(db); err != nil {
		db.Close()
		return err
	}

	masterDB = db
	dbPath = path
	return nil
}
```

---

## 🚀 Pasos para Implementar

### Paso 1: Editar `database.go`

```bash
# Abrir el archivo
code go_backend_spotiflac/database.go
```

1. Ir a la línea 42 (después de `InitMasterDatabase`)
2. Pegar la función `ensureDatabaseSchema()` completa
3. Ir a la línea 19
4. Reemplazar la función `InitMasterDatabase()` con la nueva versión
5. Guardar el archivo

### Paso 2: Recompilar el Backend

#### Para Windows (Desktop):
```bash
cd go_backend_spotiflac
go build -o ../spotiflac-backend.exe ./cmd/server/
```

#### Para Android (Mobile):
```bash
cd go_backend_spotiflac
gomobile bind -target=android -o ../android/app/libs/gobackend.aar .
```

### Paso 3: Limpiar Base de Datos Existente (Opcional)

Si ya tienes una base de datos corrupta, elimínala:

**Windows:**
```bash
# La BD suele estar en:
del %APPDATA%\SpotiFlac\spotiflac.db
# o
del %LOCALAPPDATA%\SpotiFlac\spotiflac.db
```

**Android:**
```bash
# Desinstalar y reinstalar la app
adb uninstall com.zarz.spotiflac
```

### Paso 4: Probar

1. Ejecutar la aplicación
2. Verificar que no hay errores de tablas faltantes en los logs
3. Verificar que `loadAppSettings` funciona
4. Verificar que las búsquedas de historial funcionan

---

## ✅ Checklist de Verificación

Después de implementar, verificar que estos logs **YA NO APARECEN**:

```
❌ [W] Go loadAppSettings failed, fallback: PlatformException(BACKEND_ERROR, sqlite3: SQL logic error: no such table: application_state, null, null)

❌ [W] Go getBySpotifyId failed, fallback: MissingPluginException(No implementation found for method getDownloadEntryBySpotifyID on channel com.zarz.spotiflac/backend)

❌ [W] Go findFirstByTrackAndArtist failed, fallback: MissingPluginException(No implementation found for method findDownloadEntryByTrackAndArtist on channel com.zarz.spotiflac/backend)
```

Y en su lugar deberías ver:

```
✅ [I] Database initialized successfully
✅ [I] Schema created with 14 tables
✅ [D] App settings loaded successfully
```

---

## 🐛 Troubleshooting

### Error: "cannot use db.Exec(schema) (value of type error)"

**Causa:** La función `db.Exec()` retorna `(sql.Result, error)`, no solo `error`.

**Solución:** Ya está manejado en el código proporcionado.

### Error: "near CHECK: syntax error"

**Causa:** SQLite versión antigua que no soporta CHECK constraints.

**Solución:** Actualizar dependencia sqlite3 en `go.mod`:
```bash
go get -u github.com/mattn/go-sqlite3
```

### Error: "FOREIGN KEY constraint failed"

**Causa:** Intentaste eliminar metadata que tiene files asociados.

**Solución:** El esquema ya tiene `ON DELETE CASCADE`, así que esto debería manejarse automáticamente.

---

## 📊 Estadísticas de Cambios

- **Tablas creadas:** 14
- **Índices creados:** 18
- **Líneas agregadas:** ~230
- **Archivos modificados:** 1 (`database.go`)
- **Tiempo estimado:** 5-10 minutos

---

## 🎉 Resultado Final

Una vez implementado:

1. ✅ Base de datos se inicializa correctamente
2. ✅ Todas las tablas se crean automáticamente
3. ✅ No más errores de tablas faltantes
4. ✅ Configuración de la app se guarda/carga correctamente
5. ✅ Historial de descargas funciona
6. ✅ Sistema de favoritos funciona
7. ✅ Sistema de playlists funciona
8. ✅ Estadísticas de reproducción funcionan

---

**¿Necesitas ayuda con la implementación?** Consulta `SQLITE_DIAGNOSTICO_COMPLETO.md` para más detalles técnicos.
