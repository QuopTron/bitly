package availability

import (
	"context"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
)

type platformLink struct {
	URL string `json:"url"`
}

type TrackAvailability struct {
	SpotifyID  string `json:"spotify_id"`
	Tidal      bool   `json:"tidal"`
	Amazon     bool   `json:"amazon"`
	Qobuz      bool   `json:"qobuz"`
	Deezer     bool   `json:"deezer"`
	YouTube    bool   `json:"youtube"`
	TidalURL   string `json:"tidal_url,omitempty"`
	AmazonURL  string `json:"amazon_url,omitempty"`
	QobuzURL   string `json:"qobuz_url,omitempty"`
	DeezerURL  string `json:"deezer_url,omitempty"`
	YouTubeURL string `json:"youtube_url,omitempty"`
	DeezerID   string `json:"deezer_id,omitempty"`
	QobuzID    string `json:"qobuz_id,omitempty"`
	TidalID    string `json:"tidal_id,omitempty"`
	YouTubeID  string `json:"youtube_id,omitempty"`
}

type AlbumAvailability struct {
	SpotifyID string `json:"spotify_id"`
	Deezer    bool   `json:"deezer"`
	DeezerURL string `json:"deezer_url,omitempty"`
	DeezerID  string `json:"deezer_id,omitempty"`
}

type ISRCSearcher interface {
	SearchByISRC(ctx context.Context, isrc string) (*core.TrackMetadata, error)
}
