package playback

import (
	"encoding/json"
	"fmt"
	"time"
)

func GetState() string {
	return GetStateJSON()
}

func GetHistory(limit int) string {
	return GetHistoryJSON(limit)
}

func GetQueue() string {
	return GetQueueJSON()
}

func UpdatePosition(positionMs int64) {
	SetPosition(positionMs)
}

func SyncQueueState(stateJSON string) string {
	var incoming struct {
		Tracks       []PlaybackTrack `json:"tracks"`
		CurrentIndex int             `json:"current_index"`
		Shuffle      bool            `json:"shuffle"`
		RepeatMode   string          `json:"repeat_mode"`
	}
	if err := json.Unmarshal([]byte(stateJSON), &incoming); err != nil {
		return errorResponse("Invalid state data: " + err.Error())
	}

	ps := Get()
	ps.mu.Lock()
	defer ps.mu.Unlock()

	ps.Queue = incoming.Tracks
	ps.QueueIndex = incoming.CurrentIndex
	ps.Shuffle = incoming.Shuffle
	ps.RepeatMode = incoming.RepeatMode
	ps.Timestamp = time.Now().UnixMilli()

	return fmt.Sprintf(`{"success":true,"action":"sync_queue_state","count":%d}`, len(incoming.Tracks))
}

type DownloadRequest struct {
	SpotifyID  string `json:"spotifyId"`
	TrackName  string `json:"trackName"`
	ArtistName string `json:"artistName"`
	AlbumName  string `json:"albumName"`
	CoverURL   string `json:"coverUrl"`
	ISRC       string `json:"isrc"`
	DurationMS int    `json:"durationMs"`
	Service    string `json:"service"`
	Source     string `json:"source"`
}

func TrackFromDownload(requestJSON string) (*PlaybackTrack, error) {
	var req DownloadRequest
	if err := json.Unmarshal([]byte(requestJSON), &req); err != nil {
		return nil, err
	}
	return &PlaybackTrack{
		ID:         req.SpotifyID,
		Name:       req.TrackName,
		ArtistName: req.ArtistName,
		AlbumName:  req.AlbumName,
		CoverURL:   req.CoverURL,
		ISRC:       req.ISRC,
		Duration:   req.DurationMS,
		Service:    req.Service,
		Source:     req.Source,
	}, nil
}
