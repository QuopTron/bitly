package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	backend "github.com/zarz/bitly/go_backend"
)

// rpcRequest is the JSON-RPC 2.0 request shape from DesktopBackend.
type rpcRequest struct {
	JSONRPC string                 `json:"jsonrpc"`
	ID      int64                  `json:"id"`
	Method  string                 `json:"method"`
	Params  map[string]interface{} `json:"params"`
}

// registerRPCRoute registers the JSON-RPC endpoint used by DesktopBackend.
func registerRPCRoute(mux *http.ServeMux) {
	mux.HandleFunc("/rpc", func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			http.Error(w, `{"jsonrpc":"2.0","error":"usa POST"}`, 405)
			return
		}
		body, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, `{"jsonrpc":"2.0","error":"cuerpo inválido"}`, 400)
			return
		}
		var req rpcRequest
		if err := json.Unmarshal(body, &req); err != nil || req.Method == "" {
			http.Error(w, `{"jsonrpc":"2.0","error":"payload inválido"}`, 400)
			return
		}
		result, rpcErr := dispatchRPC(req.Method, req.Params)
		resp := map[string]interface{}{"jsonrpc": "2.0", "id": req.ID}
		if rpcErr != "" {
			resp["error"] = rpcErr
		} else {
			resp["result"] = result
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	})
}

// dispatchRPC routes a JSON-RPC method to the Go backend flat exports.
func dispatchRPC(method string, params map[string]interface{}) (interface{}, string) {
	p := func() string {
		data, _ := json.Marshal(params)
		return string(data)
	}
	pGet := func(key string) string {
		if v, ok := params[key]; ok && v != nil {
			return toString(v)
		}
		return ""
	}

	switch method {
	// ── System ──────────────────────────────────────────────
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

	// ── Feed & Search ───────────────────────────────────────
	case "getHomeFeed":
		return backend.GetHomeFeed(pGet("locale")), ""
	case "getSources":
		return backend.GetSources(), ""
	case "search":
		return backend.Search(p()), ""
	case "searchStream":
		return backend.SearchStream(p()), ""
	case "getSearchStreamResults":
		return backend.GetSearchStreamResults(), ""

	// ── Detail views ────────────────────────────────────────
	case "fetchAlbumDetail":
		return backend.FetchAlbumDetail(p()), ""
	case "fetchPlaylistDetail":
		return backend.FetchPlaylistDetail(p()), ""
	case "fetchArtistDetail":
		return backend.FetchArtistDetail(p()), ""

	// ── Metadata ────────────────────────────────────────────
	case "getTrack":
		return backend.GetTrack(p()), ""
	case "getAlbum":
		return backend.GetAlbum(p()), ""
	case "getArtist":
		return backend.GetArtist(p()), ""
	case "resolveISRC":
		return backend.ResolveISRC(pGet("isrc")), ""

	// ── Actions ─────────────────────────────────────────────
	case "likeItem":
		return backend.LikeItem(p()), ""
	case "downloadItem":
		return backend.DownloadItem(p()), ""
	case "getAllDownloadProgress":
		return backend.GetAllDownloadProgress(), ""
	case "downloadByStrategy":
		return backend.DownloadByStrategy(p()), ""
	case "initItemProgress":
		return backend.InitItemProgress(p()), ""
	case "estimateTrackFileSize":
		return backend.EstimateTrackFileSize(p()), ""
	case "setDownloadDirectory":
		return backend.SetDownloadDirectory(p()), ""
	case "setBackendConfig":
		return backend.SetBackendConfig(p()), ""

	// ── Download ────────────────────────────────────────────
	case "downloadTrack":
		return backend.DownloadTrack(p()), ""
	case "downloadBatch":
		return backend.DownloadBatch(p()), ""
	case "getDownloadProgress":
		return backend.GetDownloadProgress(), ""
	case "cancelDownload":
		return backend.CancelDownload(pGet("item_id")), ""

	// ── Stream ──────────────────────────────────────────────
	case "getStreamURL":
		return backend.GetStreamURL(p()), ""
	case "getStreamPackage":
		return backend.GetStreamPackage(p()), ""
	case "startStreamingServer":
		return backend.StartStreamingServer(intFrom(params, "port", 18765)), ""
	case "stopStreamingServer":
		return backend.StopStreamingServer(), ""
	case "streamAudioChunk":
		return backend.StreamAudioChunk(p()), ""

	// ── Lyrics ──────────────────────────────────────────────
	case "fetchLyrics":
		return backend.FetchLyrics(p()), ""
	case "getLyricsLRCWithSource":
		return backend.GetLyricsLRCWithSource(p()), ""
	case "setGeniusToken":
		return backend.SetGeniusToken(pGet("token")), ""

	// ── Cache / Covers ──────────────────────────────────────
	case "getStreamCacheStats":
		return backend.GetStreamCacheStats(), ""
	case "clearStreamCache":
		return backend.ClearStreamCache(), ""
	case "setStreamCacheMaxMb":
		return backend.SetStreamCacheMaxMb(p()), ""
	case "getCoverPathForTrack":
		return backend.GetCoverPathForTrack(p()), ""
	case "saveCover":
		return backend.SaveCover(p()), ""
	case "deleteCover":
		return backend.DeleteCover(p()), ""

	// ── Extensions ──────────────────────────────────────────
	case "initExtensionSystem":
		return backend.InitExtensionSystem(p()), ""
	case "loadExtensionsFromDir":
		return backend.LoadExtensionsFromDir(p()), ""
	case "getInstalledExtensions":
		return backend.GetInstalledExtensions(), ""
	case "getBundledExtensions":
		return backend.GetBundledExtensions(), ""
	case "setExtensionSettings":
		return backend.SetExtensionSettings(p()), ""
	case "reinitializeExtension":
		return backend.ReinitializeExtension(p()), ""
	case "invokeExtensionAction":
		return backend.InvokeExtensionAction(p()), ""

	// ── YouTube OAuth ───────────────────────────────────────
	case "startYoutubeOauth":
		return backend.StartYoutubeOauth(p()), ""
	case "pollYoutubeOauth":
		return backend.PollYoutubeOauth(p()), ""
	case "exchangeYoutubeOauth":
		return backend.ExchangeYoutubeOauth(p()), ""
	case "refreshYoutubeOauth":
		return backend.RefreshYoutubeOauth(p()), ""
	case "stopYoutubeOauth":
		return backend.StopYoutubeOauth(p()), ""

	// ── Signed Session ──────────────────────────────────────
	case "getPendingVerificationUrl":
		return backend.GetPendingVerificationUrl(p()), ""
	case "triggerExtensionVerification":
		return backend.TriggerExtensionVerification(p()), ""
	case "completeSignedSessionGrant":
		return backend.CompleteSignedSessionGrant(p()), ""
	case "getSignedSessionAuthURL":
		return backend.GetSignedSessionAuthURL(pGet("extension_id")), ""
	case "getSignedSessionStatus":
		return backend.GetSignedSessionStatus(pGet("extension_id")), ""
	case "clearSignedSession":
		return backend.ClearSignedSession(pGet("extension_id")), ""
	case "setSignedSessionCallbackUrl":
		return backend.SetSignedSessionCallbackURL(pGet("url")), ""
	case "provisionSignedSessions":
		return backend.ProvisionSignedSessions(p()), ""
	case "keepAliveSignedSessions":
		return backend.KeepAliveSignedSessions(p()), ""

	// ── Premium ─────────────────────────────────────────────
	case "getPremiumStatus":
		return backend.GetPremiumStatus(), ""
	case "validatePremiumCode":
		return backend.ValidatePremiumCode(pGet("code")), ""
	case "setPremiumStatus":
		return backend.SetPremiumStatus(p()), ""
	case "checkDownloadAllowed":
		return backend.CheckDownloadAllowed(), ""

	// ── Playback ────────────────────────────────────────────
	case "reportNowPlaying":
		return backend.ReportNowPlaying(p()), ""
	case "getNowPlaying":
		return backend.GetNowPlaying(), ""
	case "markPlayed":
		return backend.MarkPlayed(p()), ""
	case "getPlayHistory":
		return backend.GetPlayHistory(intFrom(params, "limit", 20)), ""
	case "getPlayQueue":
		return backend.GetPlayQueue(), ""
	case "addToQueue":
		return backend.AddToQueue(p()), ""
	case "removeFromQueue":
		return backend.RemoveFromQueue(intFrom(params, "position", 0)), ""
	case "clearQueue":
		return backend.ClearQueue(), ""
	case "getPlaybackStats":
		return backend.GetPlaybackStats(), ""
	case "getRecommendationsFromHistory":
		return backend.GetRecommendationsFromHistory(intFrom(params, "limit", 10)), ""

	// ── Similar / Recommendations ───────────────────────────
	case "getSimilarTracks":
		return backend.GetSimilarTracks(p()), ""
	case "getSimilarArtists":
		return backend.GetSimilarArtists(p()), ""

	// ── Rescue ──────────────────────────────────────────────
	case "rescueTrack":
		return backend.RescueTrack(p()), ""
	case "rescueBatch":
		return backend.RescueBatch(p()), ""
	case "enrichMetadata":
		return backend.EnrichMetadata(pGet("isrc")), ""

	// ── Convert / Playlist / CUE ────────────────────────────
	case "convertFile":
		return backend.ConvertFile(p()), ""
	case "exportPlaylistXSPF":
		return backend.ExportPlaylistXSPF(p()), ""
	case "parsePlaylistXSPF":
		return backend.ParsePlaylistXSPF(p()), ""
	case "parseCUE":
		return backend.ParseCUE(p()), ""
	case "readFileMetadata":
		return backend.ReadFileMetadata(pGet("path")), ""
	case "writeFileMetadata":
		return backend.WriteFileMetadata(p()), ""
	case "getProviderHealthStatus":
		return backend.GetProviderHealthStatus(), ""

	// ── Library ─────────────────────────────────────────────
	case "scanLibrary":
		return backend.ScanLibrary(pGet("directory")), ""
	case "getLibraryStats":
		return backend.GetLibraryStats(), ""

	// ── Scrobble ────────────────────────────────────────────
	case "setupScrobbling":
		return backend.SetupScrobbling(p()), ""
	case "scrobbleTrack":
		return backend.ScrobbleTrack(p()), ""

	// ── Reset ───────────────────────────────────────────────
	case "resetDatabase":
		return backend.ResetDatabase(), ""

	default:
		return nil, "método no encontrado: " + method
	}
}

func toString(v interface{}) string {
	if s, ok := v.(string); ok {
		return s
	}
	if f, ok := v.(float64); ok {
		if f == float64(int64(f)) {
			return jsonInt(int64(f))
		}
		data, _ := json.Marshal(f)
		return string(data)
	}
	if b, ok := v.(bool); ok {
		if b {
			return "true"
		}
		return "false"
	}
	data, _ := json.Marshal(v)
	return string(data)
}

func jsonInt(v int64) string {
	data, _ := json.Marshal(v)
	return string(data)
}

func intFrom(params map[string]interface{}, key string, def int) int {
	if v, ok := params[key]; ok && v != nil {
		if f, ok := v.(float64); ok {
			return int(f)
		}
		if s, ok := v.(string); ok {
			var n int
			if _, err := fmt.Sscanf(s, "%d", &n); err == nil {
				return n
			}
		}
	}
	return def
}
