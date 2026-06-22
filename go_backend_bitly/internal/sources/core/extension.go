package core

type ExtTrackMetadata struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Artists     string `json:"artists"`
	AlbumName   string `json:"album_name,omitempty"`
	DurationMS  int    `json:"duration_ms"`
	TrackNumber int    `json:"track_number,omitempty"`
	ISRC        string `json:"isrc,omitempty"`
	TidalID     string `json:"tidal_id,omitempty"`
	QobuzID     string `json:"qobuz_id,omitempty"`
	Source      string `json:"source,omitempty"`
}

type ExtAlbumMetadata struct {
	ID          string             `json:"id"`
	Name        string             `json:"name"`
	Artists     string             `json:"artists"`
	ArtistID    string             `json:"artist_id,omitempty"`
	Tracks      []ExtTrackMetadata `json:"tracks"`
	CoverURL    string             `json:"cover_url,omitempty"`
	ReleaseDate string             `json:"release_date,omitempty"`
	TotalTracks int                `json:"total_tracks,omitempty"`
}

type ExtArtistMetadata struct {
	ID       string `json:"id"`
	Name     string `json:"name"`
	ImageURL string `json:"image_url,omitempty"`
}
