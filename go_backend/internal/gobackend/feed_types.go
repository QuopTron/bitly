package gobackend

// =========================================================================
// Types matching Flutter's FeedSection / FeedItem JSON schema
// =========================================================================

// FeedItemGo is the JSON shape Flutter expects from search & feed endpoints.
// Cross-provider ids are carried when the source item exposes them (search
// customSearch output, detail tracks) so playback resolves via
// CheckAvailability instead of a slow name search and the UI can match local
// Descargas a lo largo de proveedores.
type FeedItemGo struct {
	ID          string `json:"id"`
	Type        string `json:"type"`
	Name        string `json:"name"`
	Artists     string `json:"artists,omitempty"`
	CoverURL    string `json:"cover_url,omitempty"`
	Source      string `json:"source,omitempty"`
	AlbumID     string `json:"album_id,omitempty"`
	AlbumName   string `json:"album_name,omitempty"`
	DurationMs  int    `json:"duration_ms,omitempty"`
	ReleaseDate string `json:"release_date,omitempty"`
	TotalTracks int    `json:"total_tracks,omitempty"`
	Owner       string `json:"owner,omitempty"`
	ISRC        string `json:"isrc,omitempty"`
	SpotifyID   string `json:"spotify_id,omitempty"`
	DeezerID    string `json:"deezer_id,omitempty"`
	TidalID     string `json:"tidal_id,omitempty"`
	QobuzID     string `json:"qobuz_id,omitempty"`
}

// FeedSectionGo is the JSON shape Flutter expects for feed section groups.
type FeedSectionGo struct {
	Source      string       `json:"source"`
	DisplayName string       `json:"display_name"`
	Title       string       `json:"title"`
	Items       []FeedItemGo `json:"items"`
}

// =========================================================================
// HELPERS
// =========================================================================
