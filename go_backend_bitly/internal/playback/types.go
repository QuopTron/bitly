package playback

import "sync"

type PlaybackState struct {
	mu sync.RWMutex

	IsPlaying    bool            `json:"is_playing"`
	CurrentTrack *PlaybackTrack  `json:"current_track,omitempty"`
	Position     int64           `json:"position_ms"`
	Duration     int64           `json:"duration_ms"`
	Volume       float64         `json:"volume"`
	Shuffle      bool            `json:"shuffle"`
	RepeatMode   string          `json:"repeat_mode"`
	Queue        []PlaybackTrack `json:"queue,omitempty"`
	QueueIndex   int             `json:"queue_index"`
	History      []PlaybackTrack `json:"history,omitempty"`
	Timestamp    int64           `json:"timestamp"`
}

type PlaybackTrack struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	ArtistName string `json:"artist_name"`
	AlbumName  string `json:"album_name,omitempty"`
	CoverURL   string `json:"cover_url,omitempty"`
	ISRC       string `json:"isrc,omitempty"`
	Duration   int    `json:"duration_ms"`
	LocalPath  string `json:"local_path,omitempty"`
	Source     string `json:"source,omitempty"`
	Service    string `json:"service,omitempty"`
}

type PlaybackAction struct {
	Type     string                 `json:"type"`
	Track    *PlaybackTrack         `json:"track,omitempty"`
	Position int64                  `json:"position_ms,omitempty"`
	Tracks   []PlaybackTrack        `json:"tracks,omitempty"`
	Params   map[string]interface{} `json:"params,omitempty"`
}

const (
	ActionPlay            = "play"
	ActionPause           = "pause"
	ActionResume          = "resume"
	ActionStop            = "stop"
	ActionSeek            = "seek"
	ActionNext            = "next"
	ActionPrevious        = "previous"
	ActionSetQueue        = "set_queue"
	ActionAddToQueue      = "add_to_queue"
	ActionRemoveFromQueue = "remove_from_queue"
	ActionClearQueue      = "clear_queue"
	ActionSetShuffle      = "set_shuffle"
	ActionSetRepeat       = "set_repeat"
	ActionTrackCompleted  = "track_completed"
)
