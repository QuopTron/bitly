package gobackend

// =========================================================================
// DETAIL VIEWS — Flutter DetailMixin contract:
//   fetchAlbumDetail   {album_id, source}      → AlbumDetail JSON
//   fetchPlaylistDetail {collection_id, source} → PlaylistDetail JSON
//   fetchArtistDetail  {artist_id, source}     → ArtistDetail JSON
// =========================================================================

// detailTrack is Flutter's DetailTrack schema.
type detailTrack struct {
	TrackID      string `json:"trackId"`
	Name         string `json:"name"`
	DurationMs   int    `json:"durationMs"`
	TrackNumber  int    `json:"trackNumber"`
	ISRC         string `json:"isrc"`
	CoverURL     string `json:"coverUrl,omitempty"`
	CoverPath    string `json:"coverPath,omitempty"`
	FilePath     string `json:"filePath,omitempty"`
	ArtistName   string `json:"artistName,omitempty"`
	AlbumName    string `json:"albumName,omitempty"`
	IsLiked      bool   `json:"isLiked"`
	IsDownloaded bool   `json:"isDownloaded"`
	Provider     string `json:"provider,omitempty"`
	// Cross-provider ids, mirroring the reference CheckAvailabilityForItemID
	// inputs so a detail track from ANY extension (spotify, tidal, qobuz,
	// deezer) can resolve immediately on other providers instead of falling
	// back to a slow name search.
	SpotifyID string `json:"spotifyId,omitempty"`
	DeezerID  string `json:"deezerId,omitempty"`
	TidalID   string `json:"tidalId,omitempty"`
	QobuzID   string `json:"qobuzId,omitempty"`
}

// detailAlbum is Flutter's DetailAlbum schema (artist page albums).
type detailAlbum struct {
	AlbumID     string `json:"albumId"`
	Name        string `json:"name"`
	CoverURL    string `json:"coverUrl,omitempty"`
	CoverPath   string `json:"coverPath,omitempty"`
	ReleaseDate string `json:"releaseDate,omitempty"`
	TotalTracks int    `json:"totalTracks"`
	PlayCount   int    `json:"playCount"`
}
