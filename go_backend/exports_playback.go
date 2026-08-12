package gobackend

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/playback"
)

// =========================================================================
// PLAYBACK — Queue, history, now-playing
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
func GetPlayQueue() string {
	if playbackTracker == nil {
		return `[]`
	}
	queue := playbackTracker.Queue()
	data, _ := json.Marshal(queue)
	return string(data)
}

// AddToQueue adds a track to the playback queue.
func AddToQueue(payload string) string {
	if playbackTracker == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		TrackJSON string `json:"trackJSON"`
		AddedBy   string `json:"addedBy"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	var track playback.TrackInfo
	if err := json.Unmarshal([]byte(params.TrackJSON), &track); err != nil {
		return jsonError(err)
	}
	playbackTracker.AddToQueue(&track, params.AddedBy)
	return `{"ok":true}`
}

// RemoveFromQueue removes a track from queue by position.
func RemoveFromQueue(position int) string {
	if playbackTracker == nil {
		return `{"error":"no inicializado"}`
	}
	if !playbackTracker.RemoveFromQueue(position) {
		return `{"error":"posición inválida"}`
	}
	return `{"ok":true}`
}

// ReorderQueue moves a track in the queue.
func ReorderQueue(payload string) string {
	if playbackTracker == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		OldPos int `json:"oldPos"`
		NewPos int `json:"newPos"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	if !playbackTracker.ReorderQueue(params.OldPos, params.NewPos) {
		return `{"error":"posición inválida"}`
	}
	return `{"ok":true}`
}

// ClearQueue empties the playback queue.
func ClearQueue() string {
	if playbackTracker == nil {
		return `{"error":"no inicializado"}`
	}
	playbackTracker.ClearQueue()
	return `{"ok":true}`
}

// GetPlaybackStats returns playback statistics.
func GetPlaybackStats() string {
	if playbackTracker == nil {
		return `{}`
	}
	data, _ := json.Marshal(playbackTracker.Stats())
	return string(data)
}

// GetRecommendationsFromHistory returns recommended tracks based on listening history.
func GetRecommendationsFromHistory(limit int) string {
	if playbackTracker == nil {
		return `[]`
	}
	recs := playbackTracker.GetRecommendations(limit)
	data, _ := json.Marshal(recs)
	return string(data)
}
