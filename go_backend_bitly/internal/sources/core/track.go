package core

type TrackMetadata struct {
	SpotifyID   string `json:"id"`
	Name        string `json:"name"`
	Artists     string `json:"artists"`
	AlbumName   string `json:"album_name,omitempty"`
	AlbumArtist string `json:"album_artist,omitempty"`
	AlbumID     string `json:"album_id,omitempty"`
	ArtistID    string `json:"artist_id,omitempty"`
	DurationMS  int    `json:"duration_ms"`
	Images      string `json:"images,omitempty"`
	ReleaseDate string `json:"release_date,omitempty"`
	TrackNumber int    `json:"track_number,omitempty"`
	DiscNumber  int    `json:"disc_number,omitempty"`
	ExternalURL string `json:"external_url,omitempty"`
	ISRC        string `json:"isrc,omitempty"`
}

type SearchAllResult struct {
	Tracks    []TrackMetadata        `json:"tracks"`
	Artists   []SearchArtistResult   `json:"artists"`
	Albums    []SearchAlbumResult    `json:"albums"`
	Playlists []SearchPlaylistResult `json:"playlists"`
}

type SearchArtistResult struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	Images     string `json:"images,omitempty"`
	Followers  int    `json:"followers,omitempty"`
	Popularity int    `json:"popularity,omitempty"`
}

type SearchAlbumResult struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Artists     string `json:"artists"`
	Images      string `json:"images,omitempty"`
	ReleaseDate string `json:"release_date,omitempty"`
	TotalTracks int    `json:"total_tracks,omitempty"`
	AlbumType   string `json:"album_type,omitempty"`
}

type SearchPlaylistResult struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Owner       string `json:"owner,omitempty"`
	Images      string `json:"images,omitempty"`
	TotalTracks int    `json:"total_tracks,omitempty"`
}
