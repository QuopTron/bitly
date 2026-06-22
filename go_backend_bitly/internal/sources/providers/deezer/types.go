package deezer

import "time"

type deezerTrack struct {
	ID            int64             `json:"id"`
	Title         string            `json:"title"`
	Duration      int               `json:"duration"`
	TrackPosition int               `json:"track_position"`
	DiskNumber    int               `json:"disk_number"`
	ISRC          string            `json:"isrc"`
	Link          string            `json:"link"`
	ReleaseDate   string            `json:"release_date"`
	Artist        deezerArtist      `json:"artist"`
	Album         deezerAlbumSimple `json:"album"`
	Contributors  []deezerArtist    `json:"contributors"`
}

type deezerArtist struct {
	ID            int64  `json:"id"`
	Name          string `json:"name"`
	Picture       string `json:"picture"`
	PictureMedium string `json:"picture_medium"`
	PictureBig    string `json:"picture_big"`
	PictureXL     string `json:"picture_xl"`
	NbFan         int    `json:"nb_fan"`
}

type deezerAlbumSimple struct {
	ID          int64  `json:"id"`
	Title       string `json:"title"`
	Cover       string `json:"cover"`
	CoverMedium string `json:"cover_medium"`
	CoverBig    string `json:"cover_big"`
	CoverXL     string `json:"cover_xl"`
	ReleaseDate string `json:"release_date"`
	RecordType  string `json:"record_type"`
}

type deezerAlbumFull struct {
	ID          int64          `json:"id"`
	Title       string         `json:"title"`
	Cover       string         `json:"cover"`
	CoverMedium string         `json:"cover_medium"`
	CoverBig    string         `json:"cover_big"`
	CoverXL     string         `json:"cover_xl"`
	ReleaseDate string         `json:"release_date"`
	NbTracks    int            `json:"nb_tracks"`
	RecordType  string         `json:"record_type"`
	Label       string         `json:"label"`
	Copyright   string         `json:"copyright"`
	Genres      struct {
		Data []deezerGenre `json:"data"`
	} `json:"genres"`
	Artist       deezerArtist   `json:"artist"`
	Contributors []deezerArtist `json:"contributors"`
	Tracks       struct {
		Data []deezerTrack `json:"data"`
	} `json:"tracks"`
}

type deezerGenre struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
}

type deezerArtistFull struct {
	ID            int64  `json:"id"`
	Name          string `json:"name"`
	Picture       string `json:"picture"`
	PictureMedium string `json:"picture_medium"`
	PictureBig    string `json:"picture_big"`
	PictureXL     string `json:"picture_xl"`
	NbFan         int    `json:"nb_fan"`
	NbAlbum       int    `json:"nb_album"`
}

type deezerPlaylistFull struct {
	ID            int64  `json:"id"`
	Title         string `json:"title"`
	Picture       string `json:"picture"`
	PictureMedium string `json:"picture_medium"`
	PictureBig    string `json:"picture_big"`
	PictureXL     string `json:"picture_xl"`
	NbTracks      int    `json:"nb_tracks"`
	Creator       struct {
		Name string `json:"name"`
	} `json:"creator"`
	Tracks struct {
		Data []deezerTrack `json:"data"`
	} `json:"tracks"`
}

type cacheEntry struct {
	data      interface{}
	expiresAt time.Time
}

func (e *cacheEntry) isExpired() bool {
	return e == nil || time.Now().After(e.expiresAt)
}
