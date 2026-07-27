// Package playback tracks playback state, queue, and history.
// Flutter reports what's playing and Go handles the logic.
package playback

// TrackInfo holds minimal track info for playback tracking.
type TrackInfo struct {
	ID         string `json:"id"`
	Title      string `json:"title"`
	Artist     string `json:"artist"`
	ArtistID   string `json:"artistId,omitempty"`
	Album      string `json:"album,omitempty"`
	AlbumID    string `json:"albumId,omitempty"`
	DurationMs int    `json:"durationMs"`
	CoverURL   string `json:"coverUrl,omitempty"`
	Provider   string `json:"provider"`
	ISRC       string `json:"isrc,omitempty"`
}

// PlayEvent records when a track was played.
type PlayEvent struct {
	Track     TrackInfo `json:"track"`
	Timestamp int64     `json:"timestamp"`
	Duration  int       `json:"duration"` // seconds actually played
}

// QueueItem is a track in the playback queue.
type QueueItem struct {
	Track     TrackInfo `json:"track"`
	AddedBy   string    `json:"addedBy"`   // "user", "auto", "similar"
	Position  int       `json:"position"`
}
