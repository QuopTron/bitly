package gobackend

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/download"
)

// YouTube video id (any provider) and resolves a direct VIDEO-capable URL via
// El innertube route (sin yt-dlp dependency), so el completo reproductor puede stream// el visualizer immediately en su lugar de descargando un whole video archivo primero.// Payload mirrors downloadByStrategy (same strategy JSON from Flutter).
func ResolveVisualizerUrl(payload string) string {
	var params struct {
		Request string `json:"request"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil || params.Request == "" {
		return jsonErrorString("falta request")
	}
	var raw map[string]interface{}
	if err := json.Unmarshal([]byte(params.Request), &raw); err != nil {
		return jsonErrorString("request inválido")
	}
	if downloadOrch == nil {
		return jsonErrorString("no inicializado")
	}
	req := download.Request{
		ItemID:     strOf(raw, "item_id", "itemId"),
		Title:      strOf(raw, "track_title", "title", "track_name", "name"),
		Artist:     strOf(raw, "artist_name", "artist"),
		ISRC:       strOf(raw, "isrc"),
		Provider:   strOf(raw, "source", "provider"),
		TrackID:    strOf(raw, "track_id", "trackId"),
		Quality:    strOf(raw, "quality"),
		SpotifyID:  strOf(raw, "spotify_id", "spotifyId"),
		DeezerID:   strOf(raw, "deezer_id", "deezerId"),
		TidalID:    strOf(raw, "tidal_id", "tidalId"),
		QobuzID:    strOf(raw, "qobuz_id", "qobuzId"),
		DurationMS: strInt(raw, "duration_ms", "durationMs"),
	}
	url, err := downloadOrch.ResolveVisualizerStream(req, req.Quality)
	if err != nil || url == "" {
		return `{"itemId":"` + req.ItemID + `","success":false,"error":"` + err.Error() + `"}`
	}
	return `{"itemId":"` + req.ItemID + `","success":true,"url":"` + url + `","provider":"ytmusic"}`
}
