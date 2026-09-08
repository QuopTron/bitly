package main

import (
	backend "github.com/zarz/bitly/go_backend/internal/gobackend"
)

// dispatchMedia maneja los métodos de descarga, streaming, letras y cache/covers.
// Devuelve handled=false para métodos fuera de este dominio.
func dispatchMedia(method string, params map[string]interface{}) (interface{}, string, bool) {
	switch method {
	// ── Download ────────────────────────────────────────────
	case "downloadTrack":
		return backend.DownloadTrack(rpcBody(params)), "", true
	case "downloadBatch":
		return backend.DownloadBatch(rpcBody(params)), "", true
	case "getDownloadProgress":
		return backend.GetDownloadProgress(), "", true
	case "cancelDownload":
		return backend.CancelDownload(rpcGet(params, "item_id")), "", true

	// ── Stream ──────────────────────────────────────────────
	case "getStreamURL":
		return backend.GetStreamURL(rpcBody(params)), "", true
	case "getStreamPackage":
		return backend.GetStreamPackage(rpcBody(params)), "", true
	case "resolveVisualizerUrl":
		return backend.ResolveVisualizerUrl(rpcBody(params)), "", true
	case "startStreamingServer":
		return backend.StartStreamingServer(intDe(params, "port", 18765)), "", true
	case "stopStreamingServer":
		return backend.StopStreamingServer(), "", true
	case "streamAudioChunk":
		return backend.StreamAudioChunk(rpcBody(params)), "", true

	// ── Lyrics ──────────────────────────────────────────────
	case "fetchLyrics":
		return backend.FetchLyrics(rpcBody(params)), "", true
	case "getLyricsLRCWithSource":
		return backend.GetLyricsLRCWithSource(rpcBody(params)), "", true
	case "setGeniusToken":
		return backend.SetGeniusToken(rpcGet(params, "token")), "", true

	// ── Cache / Covers ──────────────────────────────────────
	case "getStreamCacheStats":
		return backend.GetStreamCacheStats(), "", true
	case "clearStreamCache":
		return backend.ClearStreamCache(), "", true
	case "setStreamCacheMaxMb":
		return backend.SetStreamCacheMaxMb(rpcBody(params)), "", true
	case "getCoverPathForTrack":
		return backend.GetCoverPathForTrack(rpcBody(params)), "", true
	case "saveCover":
		return backend.SaveCover(rpcBody(params)), "", true
	case "deleteCover":
		return backend.DeleteCover(rpcBody(params)), "", true
	}
	return nil, "", false
}
