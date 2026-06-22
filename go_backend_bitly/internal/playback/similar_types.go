package playback

import "context"

type TrackMetadata struct {
	SpotifyID   string `json:"id"`
	Name        string `json:"name"`
	Artists     string `json:"artists"`
	AlbumName   string `json:"album_name,omitempty"`
	AlbumArtist string `json:"album_artist,omitempty"`
	Images      string `json:"images,omitempty"`
	ISRC        string `json:"isrc,omitempty"`
	DurationMS  int    `json:"duration_ms"`
	ReleaseDate string `json:"release_date,omitempty"`
	TrackNumber int    `json:"track_number"`
	TotalTracks int    `json:"total_tracks"`
	DiscNumber  int    `json:"disc_number"`
	TotalDiscs  int    `json:"total_discs"`
}

func similarTrackToMap(t TrackMetadata) map[string]interface{} {
	return map[string]interface{}{
		"id":           t.SpotifyID,
		"name":         t.Name,
		"artistName":   t.Artists,
		"albumName":    t.AlbumName,
		"albumArtist":  t.AlbumArtist,
		"coverUrl":     t.Images,
		"isrc":         t.ISRC,
		"duration":     t.DurationMS,
		"source":       "deezer",
		"releaseDate":  t.ReleaseDate,
		"trackNumber":  t.TrackNumber,
		"totalTracks":  t.TotalTracks,
		"discNumber":   t.DiscNumber,
		"totalDiscs":   t.TotalDiscs,
	}
}

type DeezerSearcher interface {
	SearchAll(ctx context.Context, query string, trackLimit, artistLimit int, searchType string) (struct {
		Tracks  []TrackMetadata `json:"tracks"`
		Artists []TrackMetadata `json:"artists"`
	}, error)
	GetArtistTopTracks(ctx context.Context, artistID string, limit int) ([]TrackMetadata, error)
	GetRelatedArtists(ctx context.Context, artistID string, limit int) ([]TrackMetadata, error)
}

var deezerClient DeezerSearcher

func SetDeezerSearcher(client DeezerSearcher) {
	deezerClient = client
}

var Log = func(format string, args ...interface{}) {}

func SetLogger(logFn func(format string, args ...interface{})) {
	Log = logFn
}
