package gobackend

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/playback"
)

// =========================================================================

// ReportNowPlaying tells Go what track is currently playing.
func ReportNowPlaying(trackJSON string) string {
	if playbackTracker == nil {
		return `{"error":"no inicializado"}`
	}
	var track playback.TrackInfo
	if err := json.Unmarshal([]byte(trackJSON), &track); err != nil {
		return jsonError(err)
	}
	playbackTracker.SetNowPlaying(&track)
	return `{"ok":true}`
}

// GetNowPlaying returns the current track, or null.
func GetNowPlaying() string {
	if playbackTracker == nil {
		return `{}`
	}
	track := playbackTracker.NowPlaying()
	if track == nil {
		return `{}`
	}
	data, _ := json.Marshal(track)
	return string(data)
}

// MarkPlayed records a track as fully played.
func MarkPlayed(payload string) string {
	if playbackTracker == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		TrackJSON       string `json:"trackJSON"`
		DurationSeconds int    `json:"durationSeconds"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	var track playback.TrackInfo
	if err := json.Unmarshal([]byte(params.TrackJSON), &track); err != nil {
		return jsonError(err)
	}
	playbackTracker.MarkPlayed(&track, params.DurationSeconds)
	return `{"ok":true}`
}

// GetPlayHistory returns recent plays (newest first).
func GetPlayHistory(limit int) string {
	if playbackTracker == nil {
		return `[]`
	}
	history := playbackTracker.GetHistory(limit)
	if history == nil {
		return `[]`
	}
	data, _ := json.Marshal(history)
	return string(data)
}

// GetPlayQueue returns the current playback queue.
