package track

import "time"

// Track represents a music track in the canonical domain model.
type Track struct {
	ID              string                 `json:"id"`
	Title           string                 `json:"title"`
	NormalizedTitle string                 `json:"normalized_title"`
	ArtistID        string                 `json:"artist_id"`
	AlbumID         string                 `json:"album_id,omitempty"`
	DurationMs      int64                  `json:"duration_ms"`
	ISRC            string                 `json:"isrc,omitempty"`
	TrackNumber     int                    `json:"track_number,omitempty"`
	DiscNumber      int                    `json:"disc_number,omitempty"`
	Explicit        bool                   `json:"explicit"`
	Metadata        map[string]interface{} `json:"metadata,omitempty"`
	CreatedAt       time.Time              `json:"created_at"`
	UpdatedAt       time.Time              `json:"updated_at"`
}

// TrackWithSources is a track enriched with availability info from providers.
type TrackWithSources struct {
	Track
	Sources []TrackSource `json:"sources"`
}

// TrackSource describes availability from a single provider.
type TrackSource struct {
	Provider   string `json:"provider"`
	ProviderID string `json:"provider_id"`
	URL        string `json:"url,omitempty"`
	Quality    string `json:"quality"`
	Format     string `json:"format"`
	Available  bool   `json:"available"`
}
