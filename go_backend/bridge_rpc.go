// Bridge de export para gomobile — dispatcher genérico RPC.
//
// gomobile solo exporta funciones planas (tipos simples), así que en
// Android/Darwin cada método se repite en los bridge_*.go. Ese patrón no
// escala para mantener tres plataformas sincronizadas: cualquier export
// nuevo exige recompilar el AAR y el framework. Este archivo añade UNA
// función universal InvokeRPC(metodo, payloadJSON) que enruta por los
// mismos dispatchers del servidor JSON-RPC de escritorio, de modo que
// agregar un método nuevo en rpc_dispatch_*.go lo habilita en TODAS las
// plataformas sin tocar el bridge nativo.
//
// Se conecta con: rpc_dispatch.go (cmd/server — misma tabla de métodos,
// duplicada aquí porque cmd/server es package main) + AppDelegate.swift /
// BackendIOS (lado cliente Apple).
// Parte del flujo: bridge nativo móvil (iOS) — canal com.bitly/backend.

package gobackend

import (
	"encoding/json"

	backend "github.com/zarz/bitly/go_backend/internal/gobackend"
)

// rpcRespuesta shape JSON-RPC 2.0 de la respuesta del dispatcher.
type rpcRespuesta struct {
	Result interface{} `json:"result,omitempty"`
	Error  string      `json:"error,omitempty"`
}

// Helpers locales de params (equivalentes a rpcGet/rpcBody/intDe de
// cmd/server, duplicados porque son otro package main).

// paramObj serializa todos los params como el payload JSON que esperan
// las funciones planas del backend (casi todas reciben la cadena cruda).
func paramObj(params map[string]interface{}) string {
	data, _ := json.Marshal(params)
	return string(data)
}

// paramStr extrae un param individual como string (o "" si falta).
func paramStr(params map[string]interface{}, clave string) string {
	if v, ok := params[clave]; ok && v != nil {
		if s, ok := v.(string); ok {
			return s
		}
		data, _ := json.Marshal(v)
		return string(data)
	}
	return ""
}

// paramInt extrae un param numérico con valor por defecto.
func paramInt(params map[string]interface{}, clave string, def int) int {
	if v, ok := params[clave]; ok && v != nil {
		if f, ok := v.(float64); ok {
			return int(f)
		}
	}
	return def
}

// InvokeRPC ejecuta `metodo` con `payloadJSON` (mismo formato que el body
// JSON-RPC de escritorio: params como objeto) y devuelve la respuesta como
// JSON {"result": ...} o {"error": "..."}. Siempre devuelve texto no vacío.
func InvokeRPC(metodo string, payloadJSON string) string {
	params := map[string]interface{}{}
	if payloadJSON != "" {
		if err := json.Unmarshal([]byte(payloadJSON), &params); err != nil {
			return `{"error":"payload invalido"}`
		}
	}

	// Misma tabla de rutas que cmd/server. Duplicada porque cmd/server es
	// package main y no puede importarse; cualquier método nuevo debe
	// agregarse en AMBOS lados (ver AGENTS: rpc_dispatch_*.go).
	resultado, errStr := dispatchGomobile(metodo, params)

	resp := rpcRespuesta{Result: resultado, Error: errStr}
	data, err := json.Marshal(resp)
	if err != nil {
		return `{"error":"fallo serializando respuesta"}`
	}
	return string(data)
}

// dispatchGomobile replica dispatchRPC de cmd/server sobre el backend real
// (internal/gobackend) — los métodos son idénticos al servidor HTTP.
func dispatchGomobile(metodo string, params map[string]interface{}) (interface{}, string) {
	// Núcleo: sistema, feed/búsqueda, detalle, metadata y acciones.
	switch metodo {
	case "ping":
		return backend.Ping(), ""
	case "getBuildInfo":
		return backend.GetBuildInfo(), ""
	case "getPlatform":
		return backend.GetPlatform(), ""
	case "isMobile":
		return backend.IsMobile(), ""
	case "initGlobalState":
		return backend.InitGlobalState(), ""
	case "initBackend":
		_ = backend.InitBackend()
		return "ok", ""
	case "getHomeFeed":
		return backend.GetHomeFeed(paramStr(params, "locale")), ""
	case "getSources":
		return backend.GetSources(), ""
	case "search":
		return backend.Search(paramObj(params)), ""
	case "searchStream":
		return backend.SearchStream(paramObj(params)), ""
	case "getSearchStreamResults":
		return backend.GetSearchStreamResults(), ""
	case "fetchAlbumDetail":
		return backend.FetchAlbumDetail(paramObj(params)), ""
	case "fetchPlaylistDetail":
		return backend.FetchPlaylistDetail(paramObj(params)), ""
	case "fetchArtistDetail":
		return backend.FetchArtistDetail(paramObj(params)), ""
	case "getTrack":
		return backend.GetTrack(paramObj(params)), ""
	case "getAlbum":
		return backend.GetAlbum(paramObj(params)), ""
	case "getArtist":
		return backend.GetArtist(paramObj(params)), ""
	case "resolveISRC":
		return backend.ResolveISRC(paramStr(params, "isrc")), ""
	case "likeItem":
		return backend.LikeItem(paramObj(params)), ""
	case "downloadItem":
		return backend.DownloadItem(paramObj(params)), ""
	case "getAllDownloadProgress":
		return backend.GetAllDownloadProgress(), ""
	case "downloadByStrategy":
		return backend.DownloadByStrategy(paramObj(params)), ""
	case "initItemProgress":
		return backend.InitItemProgress(paramObj(params)), ""
	case "estimateTrackFileSize":
		return backend.EstimateTrackFileSize(paramObj(params)), ""
	case "setDownloadDirectory":
		return backend.SetDownloadDirectory(paramObj(params)), ""
	case "setBackendConfig":
		return backend.SetBackendConfig(paramObj(params)), ""
	}

	// Media: descarga, streaming, letras y cache/covers.
	switch metodo {
	case "downloadTrack":
		return backend.DownloadTrack(paramObj(params)), ""
	case "downloadBatch":
		return backend.DownloadBatch(paramObj(params)), ""
	case "getDownloadProgress":
		return backend.GetDownloadProgress(), ""
	case "cancelDownload":
		return backend.CancelDownload(paramStr(params, "item_id")), ""
	case "getStreamURL":
		return backend.GetStreamURL(paramObj(params)), ""
	case "getStreamPackage":
		return backend.GetStreamPackage(paramObj(params)), ""
	case "resolveVisualizerUrl":
		return backend.ResolveVisualizerUrl(paramObj(params)), ""
	case "startStreamingServer":
		return backend.StartStreamingServer(paramInt(params, "port", 18765)), ""
	case "stopStreamingServer":
		return backend.StopStreamingServer(), ""
	case "streamAudioChunk":
		return backend.StreamAudioChunk(paramObj(params)), ""
	case "fetchLyrics":
		return backend.FetchLyrics(paramObj(params)), ""
	case "getLyricsLRCWithSource":
		return backend.GetLyricsLRCWithSource(paramObj(params)), ""
	case "setGeniusToken":
		return backend.SetGeniusToken(paramStr(params, "token")), ""
	case "getStreamCacheStats":
		return backend.GetStreamCacheStats(), ""
	case "clearStreamCache":
		return backend.ClearStreamCache(), ""
	case "setStreamCacheMaxMb":
		return backend.SetStreamCacheMaxMb(paramObj(params)), ""
	case "getCoverPathForTrack":
		return backend.GetCoverPathForTrack(paramObj(params)), ""
	case "saveCover":
		return backend.SaveCover(paramObj(params)), ""
	case "deleteCover":
		return backend.DeleteCover(paramObj(params)), ""
	}

	// Extras: extensiones, OAuth, sesiones firmadas, premium, playback,
	// similar/rescue, convert/playlist y biblioteca.
	switch metodo {
	case "initExtensionSystem":
		return backend.InitExtensionSystem(paramObj(params)), ""
	case "loadExtensionsFromDir":
		return backend.LoadExtensionsFromDir(paramObj(params)), ""
	case "getInstalledExtensions":
		return backend.GetInstalledExtensions(), ""
	case "getBundledExtensions":
		return backend.GetBundledExtensions(), ""
	case "setExtensionSettings":
		return backend.SetExtensionSettings(paramObj(params)), ""
	case "reinitializeExtension":
		return backend.ReinitializeExtension(paramObj(params)), ""
	case "invokeExtensionAction":
		return backend.InvokeExtensionAction(paramObj(params)), ""
	case "startYoutubeOauth":
		return backend.StartYoutubeOauth(paramObj(params)), ""
	case "pollYoutubeOauth":
		return backend.PollYoutubeOauth(paramObj(params)), ""
	case "exchangeYoutubeOauth":
		return backend.ExchangeYoutubeOauth(paramObj(params)), ""
	case "refreshYoutubeOauth":
		return backend.RefreshYoutubeOauth(paramObj(params)), ""
	case "stopYoutubeOauth":
		return backend.StopYoutubeOauth(paramObj(params)), ""
	case "getPendingVerificationUrl":
		return backend.GetPendingVerificationUrl(paramObj(params)), ""
	case "triggerExtensionVerification":
		return backend.TriggerExtensionVerification(paramObj(params)), ""
	case "completeSignedSessionGrant":
		return backend.CompleteSignedSessionGrant(paramObj(params)), ""
	case "getSignedSessionAuthURL":
		return backend.GetSignedSessionAuthURL(paramStr(params, "extension_id")), ""
	case "getSignedSessionStatus":
		return backend.GetSignedSessionStatus(paramStr(params, "extension_id")), ""
	case "clearSignedSession":
		return backend.ClearSignedSession(paramStr(params, "extension_id")), ""
	case "setSignedSessionCallbackUrl":
		return backend.SetSignedSessionCallbackURL(paramStr(params, "url")), ""
	case "provisionSignedSessions":
		return backend.ProvisionSignedSessions(paramObj(params)), ""
	case "keepAliveSignedSessions":
		return backend.KeepAliveSignedSessions(paramObj(params)), ""
	case "getPremiumStatus":
		return backend.GetPremiumStatus(), ""
	case "validatePremiumCode":
		return backend.ValidatePremiumCode(paramObj(params)), ""
	case "setPremiumStatus":
		return backend.SetPremiumStatus(paramObj(params)), ""
	case "setPremiumGithubToken":
		return backend.SetPremiumGithubToken(paramObj(params)), ""
	case "checkDownloadAllowed":
		return backend.CheckDownloadAllowed(), ""
	case "reportNowPlaying":
		return backend.ReportNowPlaying(paramObj(params)), ""
	case "getNowPlaying":
		return backend.GetNowPlaying(), ""
	case "markPlayed":
		return backend.MarkPlayed(paramObj(params)), ""
	case "getPlayHistory":
		return backend.GetPlayHistory(paramInt(params, "limit", 20)), ""
	case "getPlayQueue":
		return backend.GetPlayQueue(), ""
	case "addToQueue":
		return backend.AddToQueue(paramObj(params)), ""
	case "removeFromQueue":
		return backend.RemoveFromQueue(paramInt(params, "position", 0)), ""
	case "clearQueue":
		return backend.ClearQueue(), ""
	case "getPlaybackStats":
		return backend.GetPlaybackStats(), ""
	case "getTopTracks":
		return backend.GetTopTracks(paramInt(params, "limit", 10)), ""
	case "getPlayCount":
		return backend.GetPlayCount(paramStr(params, "track_id")), ""
	case "getRecommendationsFromHistory":
		return backend.GetRecommendationsFromHistory(paramInt(params, "limit", 10)), ""
	case "getSimilarTracks":
		return backend.GetSimilarTracks(paramObj(params)), ""
	case "getSimilarArtists":
		return backend.GetSimilarArtists(paramObj(params)), ""
	case "rescueTrack":
		return backend.RescueTrack(paramObj(params)), ""
	case "rescueBatch":
		return backend.RescueBatch(paramObj(params)), ""
	case "enrichMetadata":
		return backend.EnrichMetadata(paramStr(params, "isrc")), ""
	case "convertFile":
		return backend.ConvertFile(paramObj(params)), ""
	case "exportPlaylistXSPF":
		return backend.ExportPlaylistXSPF(paramObj(params)), ""
	case "parsePlaylistXSPF":
		return backend.ParsePlaylistXSPF(paramObj(params)), ""
	case "parseCUE":
		return backend.ParseCUE(paramObj(params)), ""
	case "readFileMetadata":
		return backend.ReadFileMetadata(paramStr(params, "path")), ""
	case "writeFileMetadata":
		return backend.WriteFileMetadata(paramObj(params)), ""
	case "getProviderHealthStatus":
		return backend.GetProviderHealthStatus(), ""
	case "scanLibrary":
		return backend.ScanLibrary(paramStr(params, "directory")), ""
	case "getLibraryStats":
		return backend.GetLibraryStats(), ""
	case "setupScrobbling":
		return backend.SetupScrobbling(paramObj(params)), ""
	case "scrobbleTrack":
		return backend.ScrobbleTrack(paramObj(params)), ""
	case "updateNowPlaying":
		return backend.UpdateNowPlaying(paramObj(params)), ""
	case "resetDatabase":
		return backend.ResetDatabase(), ""
	}

	return nil, "método no encontrado: " + metodo
}
