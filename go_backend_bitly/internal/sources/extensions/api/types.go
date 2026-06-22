package api

type SearchResult struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	Artists   string `json:"artists"`
	AlbumName string `json:"album_name"`
	Duration  int64  `json:"duration_ms"`
	CoverURL  string `json:"cover_url"`
	ISRC      string `json:"isrc"`
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
