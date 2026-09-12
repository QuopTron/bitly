package gobackend

import (
	"sync"

	"github.com/zarz/bitly/go_backend/internal/extensions"
	"github.com/zarz/bitly/go_backend/internal/scrobble"
	"github.com/zarz/bitly/go_backend/internal/streaming"
)

// =========================================================================
// CANDADO DE LA CONFIGURACIÓN EN CALIENTE
// =========================================================================
//
// Flutter escribe esta configuración desde el puente en CUALQUIER momento
// (al abrir Ajustes, al cambiar la carpeta de descargas, al guardar
// credenciales) mientras otras goroutines ya la están leyendo — una descarga
// en curso, un stream sirviéndose, una búsqueda paginando o el barrido del
// caché. Antes esos globales se tocaban sin candado y eso es un data race.
//
// Por qué importa en Go:
//   - Un `string` NO es atómico: son dos palabras (puntero + longitud). Una
//     escritura concurrente puede dejar una lectura con el puntero nuevo y la
//     longitud vieja → texto corrupto, ruta equivocada o punterazo.
//   - Un `map` es peor: el runtime ABORTA el proceso con "concurrent map read
//     and map write". No es recuperable con recover(): es un crash de la app.
//
// Regla: nadie fuera de este archivo toca esos globales directo. Se entra por
// los accesores de abajo. Cada candado cubre un grupo independiente para que
// no haya ordenamientos de candado entre ellos.
var configMu sync.RWMutex

// ── Carpeta de descargas (Flutter la cambia; descargas/streams la leen) ──

func getDownloadDir() string {
	configMu.RLock()
	defer configMu.RUnlock()
	return downloadDir
}

func setDownloadDir(dir string) {
	configMu.Lock()
	downloadDir = dir
	configMu.Unlock()
}

// ── Modo de usuario ("free"/"premium"/"lifetime"; "" = aún desconocido) ──
// El modo vacío es significativo: significa "consultá premiumChecker", así que
// no se puede normalizar a "free" al leer.

func getUserMode() string {
	configMu.RLock()
	defer configMu.RUnlock()
	return userMode
}

func setUserMode(mode string) {
	configMu.Lock()
	userMode = mode
	configMu.Unlock()
}

// ── Tope del caché de streaming en MB (0 = usar el límite del plan) ─────

func getStreamCacheMaxMB() int {
	configMu.RLock()
	defer configMu.RUnlock()
	return streamCacheMaxMB
}

func setStreamCacheMaxMB(mb int) {
	configMu.Lock()
	streamCacheMaxMB = mb
	configMu.Unlock()
}

// ── Callback de Flutter ─────────────────────────────────────────────────

func getCallbackID() string {
	configMu.RLock()
	defer configMu.RUnlock()
	return flutterCallbackID
}

func setCallbackID(id string) {
	configMu.Lock()
	flutterCallbackID = id
	configMu.Unlock()
}

// =========================================================================
// AJUSTES POR EXTENSIÓN (extSettings)
// =========================================================================
//
// Este mapa lo escribe la goroutine del pool de sesiones en segundo plano
// (expandirPoolDeSesiones) al mismo tiempo que una acción de extensión lo
// lee, y que el arranque lo recorre para re-aplicar credenciales. Sin candado
// eso era un "concurrent map read and map write" — crash, no excepción.
var extSettingsMu sync.RWMutex

// getAjustesExtension devuelve el mapa de ajustes de una extensión. El
// llamador debe tratarlo como SOLO LECTURA: es el mapa vivo que el pool
// puede estar reemplazando.
func getAjustesExtension(extID string) map[string]string {
	extSettingsMu.RLock()
	defer extSettingsMu.RUnlock()
	return extSettings[extID]
}

func setAjustesExtension(extID string, settings map[string]string) {
	extSettingsMu.Lock()
	defer extSettingsMu.Unlock()
	if extSettings == nil {
		extSettings = make(map[string]map[string]string)
	}
	extSettings[extID] = settings
}

// reiniciarAjustesExtensiones vacía el mapa (arranque/reset).
func reiniciarAjustesExtensiones() {
	extSettingsMu.Lock()
	extSettings = make(map[string]map[string]string)
	extSettingsMu.Unlock()
}

// snapshotAjustesExtensiones clona el mapa completo para poder recorrerlo sin
// retener el candado: la replicación llama a la VM de JS (lento) y no puede
// quedarse con el candado mientras otra goroutine guarda ajustes.
func snapshotAjustesExtensiones() map[string]map[string]string {
	extSettingsMu.RLock()
	defer extSettingsMu.RUnlock()
	if extSettings == nil {
		return nil
	}
	copia := make(map[string]map[string]string, len(extSettings))
	for id, ajustes := range extSettings {
		copia[id] = ajustes
	}
	return copia
}

// =========================================================================
// INSTANCIAS PEREZOSAS Y DEL CICLO DE EXTENSIONES
// =========================================================================

// streamerMu cubre el servidor de streaming local. Se crea bajo demanda desde
// dos RPC distintos (StreamAudioChunk y StartStreamingServer): sin candado,
// dos pedidos simultáneos veían nil los dos y creaban DOS servidores, y el
// que perdía la carrera quedaba vivo pero inalcanzable (puerto y caché
// perdidos). El candado garantiza una sola instancia.
var streamerMu sync.Mutex

// getStreamer devuelve el servidor de streaming, creándolo la primera vez.
func getStreamer() tipoStreamer {
	streamerMu.Lock()
	defer streamerMu.Unlock()
	if streamer == nil {
		streamer = streaming.NewStreamer()
	}
	return streamer
}

// scrobbleMu cubre el cliente de scrobbling. Flutter lo configura
// (SetupScrobbling) mientras UpdateNowPlaying / Scrobble pueden estar
// reportando desde otra goroutine.
var scrobbleMu sync.RWMutex

func getScrobbleClient() *scrobble.Client {
	scrobbleMu.RLock()
	defer scrobbleMu.RUnlock()
	return scrobbleClient
}

func setScrobbleClient(c *scrobble.Client) {
	scrobbleMu.Lock()
	scrobbleClient = c
	scrobbleMu.Unlock()
}

// extRegistryMu cubre el registro de extensiones JS. Se ESCRIBE en el ciclo de
// vida del sistema de extensiones (InitGlobalState, InitExtensionSystem,
// LoadExtensionsFromDir — estos dos últimos son RPC que Flutter puede repetir)
// mientras lo LEEN las acciones de extensión y goroutines de fondo
// (retryInitializeAfterLoad, expandirPoolDeSesiones, feed).
var extRegistryMu sync.RWMutex

func getExtRegistry() *extensions.Registry {
	extRegistryMu.RLock()
	defer extRegistryMu.RUnlock()
	return extRegistry
}

func setExtRegistry(reg *extensions.Registry) {
	extRegistryMu.Lock()
	extRegistry = reg
	extRegistryMu.Unlock()
}

// =========================================================================
// SESIONES FIRMADAS POR EXTENSIÓN (sessionConfigs)
// =========================================================================
//
// Flutter guarda la configuración de la sesión firmada (Cloudflare) desde
// Ajustes mientras un GetSessionAuthURL / ExchangeSessionGrant / Refresh
// puede estar leyéndola desde otra goroutine. Mismo riesgo de crash por mapa
// concurrente que extSettings.
var sessionConfigsMu sync.RWMutex

func getSessionConfigGuardado(extID string) *extensions.SignedSessionConfig {
	sessionConfigsMu.RLock()
	defer sessionConfigsMu.RUnlock()
	if sessionConfigs == nil {
		return nil
	}
	return sessionConfigs[extID]
}

func setSessionConfigGuardado(extID string, cfg *extensions.SignedSessionConfig) {
	sessionConfigsMu.Lock()
	defer sessionConfigsMu.Unlock()
	if sessionConfigs == nil {
		sessionConfigs = make(map[string]*extensions.SignedSessionConfig)
	}
	sessionConfigs[extID] = cfg
}

// reiniciarSesionesFirmadas vacía el mapa de sesiones (arranque/reset).
func reiniciarSesionesFirmadas() {
	sessionConfigsMu.Lock()
	sessionConfigs = make(map[string]*extensions.SignedSessionConfig)
	sessionConfigsMu.Unlock()
}
