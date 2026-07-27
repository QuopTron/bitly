package tidal

// Tidal API response types

// Track represents a Tidal track.
type Track struct {
	ID          int64      `json:"id"`
	Title       string     `json:"title"`
	Duration    int        `json:"duration"`
	ISRC        string     `json:"isrc"`
	TrackNumber int        `json:"trackNumber"`
	VolumeNumber int       `json:"volumeNumber"`
	Explicit    bool       `json:"explicit"`
	Artist      ArtistRef  `json:"artist"`
	Album       AlbumRef   `json:"album"`
	StreamReady bool       `json:"streamReady"`
	StreamStartDate string `json:"streamStartDate"`
}

// Album represents a Tidal album.
type Album struct {
	ID          int64      `json:"id"`
	Title       string     `json:"title"`
	ReleaseDate string     `json:"releaseDate"`
	Cover       string     `json:"cover"`
	TrackCount  int        `json:"numberOfTracks"`
	Duration    int        `json:"duration"`
	Artist      ArtistRef  `json:"artist"`
	Tracks      *TrackList `json:"items,omitempty"`
}

// Artist represents a Tidal artist.
type Artist struct {
	ID         int64  `json:"id"`
	Name       string `json:"name"`
	PictureURL string `json:"picture"`
}

// ArtistRef is the minimal artist reference.
type ArtistRef struct {
	ID   int64  `json:"id"`
	Name string `json:"name"`
}

// AlbumRef is the minimal album reference.
type AlbumRef struct {
	ID    int64  `json:"id"`
	Title string `json:"title"`
	Cover string `json:"cover"`
}

// TrackList is a paginated list of tracks.
type TrackList struct {
	Items      []Track `json:"items"`
	TotalCount int     `json:"totalNumberOfItems"`
}

// SearchResponse is the Tidal search result wrapper.
type SearchResponse struct {
	Items      []Track `json:"items"`
	TotalCount int     `json:"totalNumberOfItems"`
}

// AlbumSearchResponse is the Tidal album search result wrapper.
type AlbumSearchResponse struct {
	Items      []Album `json:"items"`
	TotalCount int     `json:"totalNumberOfItems"`
}

// ArtistSearchResponse is the Tidal artist search result wrapper.
type ArtistSearchResponse struct {
	Items      []Artist `json:"items"`
	TotalCount int      `json:"totalNumberOfItems"`
}

// StreamURLResponse contains a Tidal stream URL.
type StreamURLResponse struct {
	URL  string `json:"url"`
	Codec string `json:"codec"`
}
