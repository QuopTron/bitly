package deezer

// No imports needed — all struct tags are compile-time only.

// Deezer API response types

// Track represents a Deezer track from the API.
type Track struct {
	ID              int64       `json:"id"`
	Title           string      `json:"title"`
	TitleShort      string      `json:"title_short"`
	TitleVersion    string      `json:"title_version"`
	Link            string      `json:"link"`
	Duration        int         `json:"duration"`
	Rank            int         `json:"rank"`
	ISRC            string      `json:"isrc"`
	Preview         string      `json:"preview"`
	MD5Origin       string      `json:"md5_origin"`
	TrackToken      string      `json:"track_token"`
	ExplicitLyrics  bool        `json:"explicit_lyrics"`
	Artist          ArtistRef   `json:"artist"`
	Album           AlbumRef    `json:"album"`
	Type            string      `json:"type"`
}

// Album represents a Deezer album from the API.
type Album struct {
	ID              int64       `json:"id"`
	Title           string      `json:"title"`
	UPC             string      `json:"upc"`
	Link            string      `json:"link"`
	Cover           string      `json:"cover"`
	CoverSmall      string      `json:"cover_small"`
	CoverMedium     string      `json:"cover_medium"`
	CoverBig        string      `json:"cover_big"`
	ReleaseDate     string      `json:"release_date"`
	RecordType      string      `json:"record_type"`
	TrackCount      int         `json:"nb_tracks"`
	Duration        int         `json:"duration"`
	Fans            int         `json:"fans"`
	Artist          ArtistRef   `json:"artist"`
	Tracks          *TrackList  `json:"tracks,omitempty"`
	Type            string      `json:"type"`
}

// Artist represents a Deezer artist from the API.
type Artist struct {
	ID              int64       `json:"id"`
	Name            string      `json:"name"`
	Link            string      `json:"link"`
	Picture         string      `json:"picture"`
	PictureSmall    string      `json:"picture_small"`
	PictureMedium   string      `json:"picture_medium"`
	PictureBig      string      `json:"picture_big"`
	TrackCount      int         `json:"nb_track"`
	AlbumCount      int         `json:"nb_album"`
	Fans            int         `json:"nb_fan"`
	Radio           bool        `json:"radio"`
	Type            string      `json:"type"`
}

// Playlist represents a Deezer playlist from the API.
type Playlist struct {
	ID              int64       `json:"id"`
	Title           string      `json:"title"`
	Description     string      `json:"description"`
	Duration        int         `json:"duration"`
	Public          bool        `json:"public"`
	TrackCount      int         `json:"nb_tracks"`
	Fans            int         `json:"fans"`
	Link            string      `json:"link"`
	Picture         string      `json:"picture"`
	PictureSmall    string      `json:"picture_small"`
	PictureMedium   string      `json:"picture_medium"`
	Creator         struct {
		ID   int64  `json:"id"`
		Name string `json:"name"`
	} `json:"creator"`
	Tracks          *TrackList  `json:"tracks,omitempty"`
	Type            string      `json:"type"`
}

// ArtistRef is the minimal artist object embedded in tracks and albums.
type ArtistRef struct {
	ID      int64  `json:"id"`
	Name    string `json:"name"`
	Picture string `json:"picture,omitempty"`
	Type    string `json:"type,omitempty"`
}

// AlbumRef is the minimal album object embedded in tracks.
type AlbumRef struct {
	ID     int64  `json:"id"`
	Title  string `json:"title"`
	Cover  string `json:"cover,omitempty"`
	Type   string `json:"type,omitempty"`
}

// TrackList is the paginated track list inside an album or playlist.
type TrackList struct {
	Data []Track `json:"data"`
}

// SearchResponse is the paginated search result wrapper.
type SearchResponse struct {
	Data  []Track `json:"data"`
	Total int     `json:"total"`
	Next  string  `json:"next,omitempty"`
}

// ErrorResponse is the Deezer API error format.
type ErrorResponse struct {
	Error struct {
		Type   string `json:"type"`
		Message string `json:"message"`
		Code   int    `json:"code"`
	} `json:"error"`
}
