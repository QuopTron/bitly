package gobackend

import (
	"encoding/json"

	"github.com/zarz/bitly/go_backend/internal/playback"
)

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
