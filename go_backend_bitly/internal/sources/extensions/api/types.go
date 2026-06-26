package api

// SearchResult holds all fields returned by extension customSearch,
// matching upstream ExtTrackMetadata (https://github.com/spotiflacapp/SpotiFLAC-Mobile).
// Non-empty fields are included in the JSON response; empty/zero fields are omitted.
type SearchResult struct {
	ID          string `json:"id,omitempty"`
	Name        string `json:"name,omitempty"`
	Artists     string `json:"artists,omitempty"`
	AlbumName   string `json:"album_name,omitempty"`
	AlbumArtist string `json:"album_artist,omitempty"`
	AlbumID     string `json:"album_id,omitempty"`
	ArtistID    string `json:"artist_id,omitempty"`
	DurationMS  int64  `json:"duration_ms,omitempty"`
	CoverURL    string `json:"cover_url,omitempty"`
	Images      string `json:"images,omitempty"`
	ReleaseDate string `json:"release_date,omitempty"`
	TrackNumber int    `json:"track_number,omitempty"`
	TotalTracks int    `json:"total_tracks,omitempty"`
	DiscNumber  int    `json:"disc_number,omitempty"`
	ISRC        string `json:"isrc,omitempty"`
	ProviderID  string `json:"provider_id,omitempty"`
	ItemType    string `json:"item_type,omitempty"`
	AlbumType   string `json:"album_type,omitempty"`
	Owner       string `json:"owner,omitempty"`
	Label       string `json:"label,omitempty"`
	Genre       string `json:"genre,omitempty"`
	Composer    string `json:"composer,omitempty"`
	AudioQuality string `json:"audio_quality,omitempty"`
	AudioModes  string `json:"audio_modes,omitempty"`
	TidalID     string `json:"tidal_id,omitempty"`
	QobuzID     string `json:"qobuz_id,omitempty"`
	DeezerID    string `json:"deezer_id,omitempty"`
	SpotifyID   string `json:"spotify_id,omitempty"`
}

type TrackMetadata struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Artists     string `json:"artists"`
	AlbumName   string `json:"album_name"`
	AlbumArtist string `json:"album_artist"`
	DurationMs  int64  `json:"duration_ms"`
	CoverURL    string `json:"cover_url"`
	ISRC        string `json:"isrc"`
	TrackNumber int    `json:"track_number"`
	Genre       string `json:"genre"`
	Label       string `json:"label"`
	Composer    string `json:"composer"`
}

type AlbumMetadata struct {
	ID          string          `json:"id"`
	Name        string          `json:"name"`
	Artists     string          `json:"artists"`
	CoverURL    string          `json:"cover_url"`
	ReleaseDate string          `json:"release_date"`
	TotalTracks int             `json:"total_tracks"`
	Tracks      []TrackMetadata `json:"tracks"`
}

type ArtistMetadata struct {
	ID        string           `json:"id"`
	Name      string           `json:"name"`
	ImageURL  string           `json:"image_url"`
	Albums    []AlbumMetadata  `json:"albums"`
	TopTracks []TrackMetadata  `json:"top_tracks"`
}

type AvailabilityResult struct {
	Available    bool   `json:"available"`
	TrackID      string `json:"track_id,omitempty"`
	SkipFallback bool   `json:"skip_fallback,omitempty"`
	Reason       string `json:"reason,omitempty"`
}

type DownloadResult struct {
	Success    bool   `json:"success"`
	FilePath   string `json:"file_path,omitempty"`
	BitDepth   int    `json:"bit_depth,omitempty"`
	SampleRate int    `json:"sample_rate,omitempty"`
	Error      string `json:"error,omitempty"`
}

type URLHandleResult struct {
	Type     string          `json:"type"`
	Track    *TrackMetadata  `json:"track,omitempty"`
	Tracks   []TrackMetadata `json:"tracks,omitempty"`
	Album    *AlbumMetadata  `json:"album,omitempty"`
	Artist   *ArtistMetadata `json:"artist,omitempty"`
	Name     string          `json:"name,omitempty"`
	CoverURL string          `json:"cover_url,omitempty"`
}

type LyricLine struct {
	StartTimeMs int64  `json:"startTimeMs"`
	Words       string `json:"words"`
	EndTimeMs   int64  `json:"endTimeMs"`
}

type LyricsResult struct {
	Lines        []LyricLine `json:"lines"`
	SyncType     string      `json:"syncType"`
	Instrumental bool        `json:"instrumental"`
	PlainLyrics  string      `json:"plainLyrics"`
}
