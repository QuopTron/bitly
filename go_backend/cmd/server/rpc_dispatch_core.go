package main

import (
	backend "github.com/zarz/bitly/go_backend/internal/gobackend"
)

// dispatchCore handles system, feed/search, detail, metadata and actions
// methods. Returns handled=false for methods outside this domain.
func dispatchCore(method string, params map[string]interface{}) (interface{}, string, bool) {
	switch method {
	// ── System ──────────────────────────────────────────────
	case "ping":
		return backend.Ping(), "", true
	case "getBuildInfo":
		return backend.GetBuildInfo(), "", true
	case "getPlatform":
		return backend.GetPlatform(), "", true
	case "isMobile":
		return backend.IsMobile(), "", true
	case "initGlobalState":
		return backend.InitGlobalState(), "", true
	case "initBackend":
		_ = backend.InitBackend()
		return "ok", "", true

	// ── Feed & Search ───────────────────────────────────────
	case "getHomeFeed":
		return backend.GetHomeFeed(rpcGet(params, "locale")), "", true
	case "getSources":
		return backend.GetSources(), "", true
	case "search":
		return backend.Search(rpcBody(params)), "", true
	case "searchStream":
		return backend.SearchStream(rpcBody(params)), "", true
	case "getSearchStreamResults":
		return backend.GetSearchStreamResults(), "", true

	// ── Detail views ────────────────────────────────────────
	case "fetchAlbumDetail":
		return backend.FetchAlbumDetail(rpcBody(params)), "", true
	case "fetchPlaylistDetail":
		return backend.FetchPlaylistDetail(rpcBody(params)), "", true
	case "fetchArtistDetail":
		return backend.FetchArtistDetail(rpcBody(params)), "", true

	// ── Metadata ────────────────────────────────────────────
	case "getTrack":
		return backend.GetTrack(rpcBody(params)), "", true
	case "getAlbum":
		return backend.GetAlbum(rpcBody(params)), "", true
	case "getArtist":
		return backend.GetArtist(rpcBody(params)), "", true
	case "resolveISRC":
		return backend.ResolveISRC(rpcGet(params, "isrc")), "", true

	// ── Actions ─────────────────────────────────────────────
	case "likeItem":
		return backend.LikeItem(rpcBody(params)), "", true
	case "downloadItem":
		return backend.DownloadItem(rpcBody(params)), "", true
	case "getAllDownloadProgress":
		return backend.GetAllDownloadProgress(), "", true
	case "downloadByStrategy":
		return backend.DownloadByStrategy(rpcBody(params)), "", true
	case "initItemProgress":
		return backend.InitItemProgress(rpcBody(params)), "", true
	case "estimateTrackFileSize":
		return backend.EstimateTrackFileSize(rpcBody(params)), "", true
	case "setDownloadDirectory":
		return backend.SetDownloadDirectory(rpcBody(params)), "", true
	case "setBackendConfig":
		return backend.SetBackendConfig(rpcBody(params)), "", true
	}
	return nil, "", false
}
