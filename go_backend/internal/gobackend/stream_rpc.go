package gobackend

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/streaming"
)

// =========================================================================
// STREAMING
// =========================================================================

func GetStreamURL(payload string) string {
	var params struct {
		ProviderName string `json:"providerName"`
		TrackID      string `json:"trackID"`
		Quality      string `json:"quality"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	p := reg.Get(params.ProviderName)
	if p == nil {
		return jsonErrorString("proveedor no encontrado")
	}
	url, err := p.GetStreamURL(params.TrackID, params.Quality)
	if err != nil {
		return jsonError(err)
	}
	return `{"url":"` + url + `"}`
}

// StartStreamingServer starts an HTTP proxy for audio streaming (desktop).
func StartStreamingServer(port int) string {
	if streamer == nil {
		streamer = streaming.NewStreamer()
	}
	addr, err := streamer.StartServer(port)
	if err != nil {
		return jsonError(err)
	}
	return `{"url":"` + addr + `"}`
}

// StopStreamingServer stops the streaming HTTP server.
func StopStreamingServer() string {
	if streamer == nil {
		return `{"ok":true}`
	}
	if err := streamer.StopServer(); err != nil {
		return jsonError(err)
	}
	return `{"ok":true}`
}

// GetStreamPackage returns a complete stream package: audio URL + metadata + lyrics + cover.
