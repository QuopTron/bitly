package core

type AlbumResponsePayload struct {
	AlbumInfo AlbumInfoMetadata    `json:"album_info"`
	TrackList []AlbumTrackMetadata `json:"track_list"`
}

type AlbumInfoMetadata struct {
	TotalTracks int    `json:"total_tracks"`
	Name        string `json:"name"`
	ReleaseDate string `json:"release_date,omitempty"`
	Artists     string `json:"artists"`
	ArtistId    string `json:"artist_id,omitempty"`
	Images      string `json:"images,omitempty"`
	Genre       string `json:"genre,omitempty"`
	Label       string `json:"label,omitempty"`
	Copyright   string `json:"copyright,omitempty"`
}

type AlbumTrackMetadata struct {
	SpotifyID   string `json:"id"`
	Artists     string `json:"artists"`
	Name        string `json:"name"`
	AlbumName   string `json:"album_name,omitempty"`
	AlbumArtist string `json:"album_artist,omitempty"`
	DurationMS  int    `json:"duration_ms"`
	Images      string `json:"images,omitempty"`
	ReleaseDate string `json:"release_date,omitempty"`
	TrackNumber int    `json:"track_number,omitempty"`
	TotalTracks int    `json:"total_tracks,omitempty"`
	DiscNumber  int    `json:"disc_number,omitempty"`
	TotalDiscs  int    `json:"total_discs,omitempty"`
	ExternalURL string `json:"external_url,omitempty"`
	ISRC        string `json:"isrc,omitempty"`
	AlbumID     string `json:"album_id,omitempty"`
	AlbumType   string `json:"album_type,omitempty"`
}

type ArtistResponsePayload struct {
	ArtistInfo ArtistInfoMetadata   `json:"artist_info"`
	Albums     []ArtistAlbumMetadata `json:"albums"`
}

type ArtistInfoMetadata struct {
	ID         string `json:"id"`
	Name       string `json:"name"`
	Images     string `json:"images,omitempty"`
	Followers  int    `json:"followers,omitempty"`
	Popularity int    `json:"popularity,omitempty"`
}

type ArtistAlbumMetadata struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	ReleaseDate string `json:"release_date,omitempty"`
	TotalTracks int    `json:"total_tracks,omitempty"`
	Images      string `json:"images,omitempty"`
	AlbumType   string `json:"album_type,omitempty"`
	Artists     string `json:"artists,omitempty"`
}

type PlaylistResponsePayload struct {
	PlaylistInfo PlaylistInfoMetadata `json:"playlist_info"`
	TrackList    []AlbumTrackMetadata `json:"track_list"`
}

type PlaylistInfoMetadata struct {
	Tracks struct {
		Total int `json:"total"`
	} `json:"tracks"`
	Owner struct {
		DisplayName string `json:"display_name"`
		Name        string `json:"name,omitempty"`
		Images      string `json:"images,omitempty"`
	} `json:"owner"`
}

type TrackResponse struct {
	Track TrackMetadata `json:"track"`
}
