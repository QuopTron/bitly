package gobackend

import (
	"encoding/json"
)

// =========================================================================
// LYRICS
// =========================================================================

// SetGeniusToken configures the Genius access token for lyrics search.
func SetGeniusToken(token string) string {
	if lyricsClient == nil {
		return `{"error":"no inicializado"}`
	}
	lyricsClient.SetGeniusToken(token)
	return `{"ok":true}`
}

func FetchLyrics(payload string) string {
	if lyricsClient == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		TrackName  string `json:"trackName"`
		ArtistName string `json:"artistName"`
		DurationMs int64  `json:"durationMs"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	lyrics, err := lyricsClient.GetLyrics(params.TrackName, params.ArtistName, int(params.DurationMs))
	if err != nil {
		return jsonError(err)
	}
	data, _ := json.Marshal(lyrics)
	return string(data)
}

// GetLyricsLRCWithSource returns lyrics for the player with the Flutter contract
// {lyrics, instrumental}. Flutter contract: {track_name, artist_name, duration_ms}.
func GetLyricsLRCWithSource(payload string) string {
	if lyricsClient == nil {
		return `{"lyrics":"","instrumental":false}`
	}
	var params struct {
		TrackName  string `json:"track_name"`
		ArtistName string `json:"artist_name"`
		DurationMs int64  `json:"duration_ms"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"lyrics":"","instrumental":false}`
	}
	if params.TrackName == "" || params.ArtistName == "" {
		return `{"lyrics":"","instrumental":false}`
	}
	lyrics, err := lyricsClient.GetLyrics(params.TrackName, params.ArtistName, int(params.DurationMs))
	if err != nil || lyrics == nil {
		return `{"lyrics":"","instrumental":false}`
	}
	text := lyrics.PlainLyrics
	if text == "" {
		text = lyrics.SyncedLyrics
	}
	instrumental := text == ""
	data, _ := json.Marshal(map[string]interface{}{
		"lyrics":       text,
		"instrumental": instrumental,
	})
	return string(data)
}
