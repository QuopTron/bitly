// Tabla única de métodos RPC del backend.
//
// Este archivo es LA fuente de verdad del contrato RPC: lo consumen tanto el
// servidor JSON-RPC de escritorio/web (cmd/server/rpc_dispatch.go) como el
// dispatcher genérico de móvil (bridge_rpc.go → InvokeRPC). Antes había tres
// tablas duplicadas a mano (cmd/server/rpc_dispatch_*.go, dispatchGomobile y
// los exports planos de bridge_*.go) que divergían: getSearchConfig no
// existía en escritorio, enviarReporte no existía en iOS, descargarFuente no
// existía en Android, etc. Ahora un método nuevo se agrega UNA sola vez aquí
// y queda habilitado en todas las plataformas.
//
// El guard TestTablaRPCCubreFlutter (rpc_tabla_test.go) falla si Flutter
// llama a un método que no está en este mapa.
//
// Se conecta con: cmd/server/rpc_dispatch.go, bridge_rpc.go,
// lib/core/backend_go/** (rpcCall del lado Dart).
// Parte del flujo: transporte RPC (HTTP en escritorio, InvokeRPC en móvil).

package gobackend

import (
	"encoding/json"
	"fmt"
	"sort"
)

// rpcManejador ejecuta un método RPC con params ya decodificados. Devuelve el
// resultado (casi siempre un string con JSON) y un error en texto plano.
type rpcManejador func(params map[string]interface{}) (interface{}, string)

// tablaRPC es el mapa completo de métodos. Las claves son únicas: si se
// duplica una, el paquete no compila.
var tablaRPC = map[string]rpcManejador{
	// ── Sistema ─────────────────────────────────────────────────────
	"ping":            sinParametros(func() string { return Ping() }),
	"getBuildInfo":    sinParametros(GetBuildInfo),
	"getPlatform":     sinParametros(GetPlatform),
	"initGlobalState": sinParametros(InitGlobalState),
	"isMobile":        soloBool(IsMobile),
	"initBackend":     accion(InitBackend),

	// ── Feed y búsqueda ─────────────────────────────────────────────
	"getHomeFeed":            conTexto("locale", GetHomeFeed),
	"getSources":             sinParametros(GetSources),
	"search":                 conJSON(Search),
	"searchStream":           conJSON(SearchStream),
	"getSearchStreamResults": sinParametros(GetSearchStreamResults),
	"getSearchConfig":        sinParametros(GetSearchConfig),
	"resolveUrl":             conJSON(ResolveUrl),

	// ── Detalle ─────────────────────────────────────────────────────
	"fetchAlbumDetail":    conJSON(FetchAlbumDetail),
	"fetchPlaylistDetail": conJSON(FetchPlaylistDetail),
	"fetchArtistDetail":   conJSON(FetchArtistDetail),

	// ── Metadata ────────────────────────────────────────────────────
	"getTrack":    conJSON(GetTrack),
	"getAlbum":    conJSON(GetAlbum),
	"getArtist":   conJSON(GetArtist),
	"resolveISRC": conTexto("isrc", ResolveISRC),

	// ── Acciones ────────────────────────────────────────────────────
	"likeItem":                    conJSON(LikeItem),
	"downloadItem":                conJSON(DownloadItem),
	"getAllDownloadProgress":      sinParametros(GetAllDownloadProgress),
	"downloadByStrategy":          conJSON(DownloadByStrategy),
	"initItemProgress":            conJSON(InitItemProgress),
	"estimateTrackFileSize":       conJSON(EstimateTrackFileSize),
	"setDownloadDirectory":        conJSON(SetDownloadDirectory),
	"setBackendConfig":            conJSON(SetBackendConfig),
	"setDownloadProviderPriority": conJSON(SetDownloadProviderPriority),

	// ── Descarga ────────────────────────────────────────────────────
	"downloadTrack":       conJSON(DownloadTrack),
	"downloadBatch":       conJSON(DownloadBatch),
	"getDownloadProgress": sinParametros(GetDownloadProgress),
	"cancelDownload":      conTexto("item_id", CancelDownload),

	// ── Streaming ───────────────────────────────────────────────────
	"getStreamURL":         conJSON(GetStreamURL),
	"getStreamPackage":     conJSON(GetStreamPackage),
	"resolveVisualizerUrl": conJSON(ResolveVisualizerUrl),
	"startStreamingServer": conEntero("port", 18765, StartStreamingServer),
	"stopStreamingServer":  sinParametros(StopStreamingServer),
	"streamAudioChunk":     conJSON(StreamAudioChunk),

	// ── Letras ──────────────────────────────────────────────────────
	"fetchLyrics":            conJSON(FetchLyrics),
	"getLyricsLRCWithSource": conJSON(GetLyricsLRCWithSource),
	"setGeniusToken":         conTexto("token", SetGeniusToken),

	// ── Caché, carátulas y memoria ──────────────────────────────────
	"getStreamCacheStats":   sinParametros(GetStreamCacheStats),
	"clearStreamCache":      sinParametros(ClearStreamCache),
	"deleteStreamCacheFile": conJSON(DeleteStreamCacheFile),
	"liberarMemoria":        sinParametros(LiberarMemoria),
	"setStreamCacheMaxMb":   conJSON(SetStreamCacheMaxMb),
	"getCoverPathForTrack":  conJSON(GetCoverPathForTrack),
	"saveCover":             conJSON(SaveCover),
	"deleteCover":           conJSON(DeleteCover),

	// ── Tipografías (Ajustes → Apariencia) ──────────────────────────
	"descargarFuente": conJSON(DescargarFuente),
	"borrarFuentes":   sinParametros(BorrarFuentes),

	// ── Extensiones ─────────────────────────────────────────────────
	"initExtensionSystem":    conJSON(InitExtensionSystem),
	"loadExtensionsFromDir":  conJSON(LoadExtensionsFromDir),
	"getInstalledExtensions": sinParametros(GetInstalledExtensions),
	"getBundledExtensions":   sinParametros(GetBundledExtensions),
	"setExtensionSettings":   conJSON(SetExtensionSettings),
	"soulseekConectar":       conJSON(ConectarSoulseek),
	"reinitializeExtension":  conJSON(ReinitializeExtension),
	"invokeExtensionAction":  conJSON(InvokeExtensionAction),

	// ── OAuth de YouTube ────────────────────────────────────────────
	"startYoutubeOauth":    conJSON(StartYoutubeOauth),
	"pollYoutubeOauth":     conJSON(PollYoutubeOauth),
	"exchangeYoutubeOauth": conJSON(ExchangeYoutubeOauth),
	"refreshYoutubeOauth":  conJSON(RefreshYoutubeOauth),
	"stopYoutubeOauth":     conJSON(StopYoutubeOauth),

	// ── Sesiones firmadas ───────────────────────────────────────────
	"getPendingVerificationUrl":    conJSON(GetPendingVerificationUrl),
	"triggerExtensionVerification": conJSON(TriggerExtensionVerification),
	"completeSignedSessionGrant":   conJSON(CompleteSignedSessionGrant),
	"getSignedSessionAuthURL":      conTexto("extension_id", GetSignedSessionAuthURL),
	"getSignedSessionStatus":       conTexto("extension_id", GetSignedSessionStatus),
	"clearSignedSession":           conTexto("extension_id", ClearSignedSession),
	"setSignedSessionCallbackUrl":  conTexto("url", SetSignedSessionCallbackURL),
	"provisionSignedSessions":      conJSON(ProvisionSignedSessions),
	"keepAliveSignedSessions":      conJSON(KeepAliveSignedSessions),

	// ── Premium ─────────────────────────────────────────────────────
	"getPremiumStatus":      sinParametros(GetPremiumStatus),
	"validatePremiumCode":   conJSON(ValidatePremiumCode),
	"setPremiumStatus":      conJSON(SetPremiumStatus),
	"setPremiumGithubToken": conJSON(SetPremiumGithubToken),
	"enviarReporte":         conJSON(EnviarReporte),
	"checkDownloadAllowed":  sinParametros(CheckDownloadAllowed),

	// ── Reproducción ────────────────────────────────────────────────
	"reportNowPlaying":              conJSON(ReportNowPlaying),
	"getNowPlaying":                 sinParametros(GetNowPlaying),
	"markPlayed":                    conJSON(MarkPlayed),
	"getPlayHistory":                conEntero("limit", 20, GetPlayHistory),
	"getPlayQueue":                  sinParametros(GetPlayQueue),
	"addToQueue":                    conJSON(AddToQueue),
	"removeFromQueue":               conEntero("position", 0, RemoveFromQueue),
	"clearQueue":                    sinParametros(ClearQueue),
	"getPlaybackStats":              sinParametros(GetPlaybackStats),
	"getTopTracks":                  conEntero("limit", 10, GetTopTracks),
	"getPlayCount":                  conTexto("track_id", GetPlayCount),
	"getRecommendationsFromHistory": conEntero("limit", 10, GetRecommendationsFromHistory),

	// ── Similares y recomendaciones ─────────────────────────────────
	"getSimilarTracks":  conJSON(GetSimilarTracks),
	"getSimilarArtists": conJSON(GetSimilarArtists),

	// ── Rescate ─────────────────────────────────────────────────────
	"rescueTrack":    conJSON(RescueTrack),
	"rescueBatch":    conJSON(RescueBatch),
	"enrichMetadata": conTexto("isrc", EnrichMetadata),

	// ── Conversión / playlists / CUE ────────────────────────────────
	"convertFile":             conJSON(ConvertFile),
	"exportPlaylistXSPF":      conJSON(ExportPlaylistXSPF),
	"parsePlaylistXSPF":       conJSON(ParsePlaylistXSPF),
	"parseCUE":                conJSON(ParseCUE),
	"readFileMetadata":        conTexto("path", ReadFileMetadata),
	"writeFileMetadata":       conJSON(WriteFileMetadata),
	"getProviderHealthStatus": sinParametros(GetProviderHealthStatus),

	// ── Biblioteca local ────────────────────────────────────────────
	"scanLibrary":             conTexto("directory", ScanLibrary),
	"importarBibliotecaLocal": conTexto("directory", ImportarBibliotecaLocal),
	"faltantesLocales":        conTexto("isrcs", FaltantesLocales),
	"rutaLocalIsrc":           conTexto("isrc", RutaLocalISRC),
	"getLibraryStats":         sinParametros(GetLibraryStats),

	// ── Scrobble ────────────────────────────────────────────────────
	"setupScrobbling":  conJSON(SetupScrobbling),
	"scrobbleTrack":    conJSON(ScrobbleTrack),
	"updateNowPlaying": conJSON(UpdateNowPlaying),

	// ── Mantenimiento ───────────────────────────────────────────────
	"resetDatabase": sinParametros(ResetDatabase),
}

// DispatchRPC enruta `metodo` con sus `params` ya decodificados. Es el único
// punto de entrada al contrato RPC: lo usan el servidor HTTP de escritorio y
// InvokeRPC en Android/iOS.
func DispatchRPC(metodo string, params map[string]interface{}) (interface{}, string) {
	if params == nil {
		params = map[string]interface{}{}
	}
	if manejador, ok := tablaRPC[metodo]; ok {
		return manejador(params)
	}
	return nil, "método no encontrado: " + metodo
}

// MetodosRPC devuelve los nombres de todos los métodos soportados, ordenados.
// Lo usa el test guard para cruzar el contrato con las llamadas de Flutter.
func MetodosRPC() []string {
	metodos := make([]string, 0, len(tablaRPC))
	for metodo := range tablaRPC {
		metodos = append(metodos, metodo)
	}
	sort.Strings(metodos)
	return metodos
}

// ── Constructores de manejadores ────────────────────────────────────────
//
// Cada forma de parámetro tiene su propio constructor: así el manejador
// decide en un solo sitio si el método recibe todo el payload, un texto
// suelto o un entero, en lugar de repetirlo en tres dispatchers.

// sinParametros ignora params y llama sin argumentos.
func sinParametros(f func() string) rpcManejador {
	return func(map[string]interface{}) (interface{}, string) {
		return f(), ""
	}
}

// conJSON serializa params completo como el payload JSON que esperan las
// funciones planas del backend (casi todas reciben la cadena cruda).
func conJSON[T any](f func(string) T) rpcManejador {
	return func(params map[string]interface{}) (interface{}, string) {
		return f(paramObj(params)), ""
	}
}

// conTexto extrae un único parámetro como string y lo pasa a la función.
func conTexto[T any](clave string, f func(string) T) rpcManejador {
	return func(params map[string]interface{}) (interface{}, string) {
		return f(paramStr(params, clave)), ""
	}
}

// conEntero extrae un parámetro numérico con valor por defecto.
func conEntero[T any](clave string, def int, f func(int) T) rpcManejador {
	return func(params map[string]interface{}) (interface{}, string) {
		return f(paramInt(params, clave, def)), ""
	}
}

// soloBool adapta una función que devuelve bool (isMobile).
func soloBool(f func() bool) rpcManejador {
	return func(map[string]interface{}) (interface{}, string) {
		return f(), ""
	}
}

// accion adapta initBackend, que devuelve error y se traduce a "ok".
func accion(f func() error) rpcManejador {
	return func(map[string]interface{}) (interface{}, string) {
		_ = f()
		return "ok", ""
	}
}

// ── Helpers de params ───────────────────────────────────────────────────

// paramObj serializa todos los params como el payload JSON que esperan las
// funciones planas del backend.
func paramObj(params map[string]interface{}) string {
	data, _ := json.Marshal(params)
	return string(data)
}

// paramStr extrae un param individual como string (o "" si falta).
func paramStr(params map[string]interface{}, clave string) string {
	v, ok := params[clave]
	if !ok || v == nil {
		return ""
	}
	if s, ok := v.(string); ok {
		return s
	}
	data, _ := json.Marshal(v)
	return string(data)
}

// paramInt extrae un param numérico con valor por defecto.
func paramInt(params map[string]interface{}, clave string, def int) int {
	v, ok := params[clave]
	if !ok || v == nil {
		return def
	}
	switch n := v.(type) {
	case float64:
		return int(n)
	case string:
		var entero int
		if _, err := fmt.Sscanf(n, "%d", &entero); err == nil {
			return entero
		}
	}
	return def
}
