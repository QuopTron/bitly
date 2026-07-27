package qobuz

// Qobuz API response types

// Track represents a Qobuz track.
type Track struct {
	ID           int64    `json:"id"`
	Title        string   `json:"title"`
	Duration     int      `json:"duration"`
	ISRC         string   `json:"isrc"`
	TrackNumber  int      `json:"track_number"`
	Streamable   bool     `json:"streamable"`
	MaximumBitrate int    `json:"maximum_bitrate"`
	Album        *Album   `json:"album,omitempty"`
	Performer    *Artist  `json:"performer,omitempty"`
}

// Album represents a Qobuz album.
type Album struct {
	ID            int64    `json:"id"`
	Title         string   `json:"title"`
	UPC           string   `json:"upc"`
	ReleaseDate   string   `json:"release_date"`
	Duration      int      `json:"duration"`
	TrackCount    int      `json:"tracks_count"`
	MaximumBitrate int     `json:"maximum_bitrate"`
	Image         Image    `json:"image"`
	Artist        *Artist  `json:"artist,omitempty"`
	Tracks        *struct {
		Items []Track `json:"items"`
	} `json:"tracks,omitempty"`
}

// Artist represents a Qobuz artist.
type Artist struct {
	ID      int64  `json:"id"`
	Name    string `json:"name"`
	Image   Image  `json:"image"`
	AlbumsCount int `json:"albums_count"`
}

// Image represents an image in various sizes.
type Image struct {
	Large  string `json:"large"`
	Medium string `json:"medium"`
	Small  string `json:"small"`
	Thumb  string `json:"thumbnail"`
}

// SearchResponse is the Qobuz search result wrapper.
type SearchResponse struct {
	Tracks *struct {
		Items []Track `json:"items"`
		Total int     `json:"total"`
	} `json:"tracks,omitempty"`
	Albums *struct {
		Items []Album `json:"items"`
		Total int     `json:"total"`
	} `json:"albums,omitempty"`
	Artists *struct {
		Items []Artist `json:"items"`
		Total int      `json:"total"`
	} `json:"artists,omitempty"`
}

// TrackFileURLResponse contains the stream URL response.
type TrackFileURLResponse struct {
	URL string `json:"url"`
}
