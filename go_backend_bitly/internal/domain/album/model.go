package album

// Album represents a music album/EP/single.
type Album struct {
	ID         string                 `json:"id"`
	Title      string                 `json:"title"`
	ArtistID   string                 `json:"artist_id"`
	Year       int                    `json:"year,omitempty"`
	CoverURL   string                 `json:"cover_url,omitempty"`
	TrackCount int                    `json:"track_count"`
	Metadata   map[string]interface{} `json:"metadata,omitempty"`
}
