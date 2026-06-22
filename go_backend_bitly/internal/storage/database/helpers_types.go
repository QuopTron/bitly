package database

type DownloadHistoryEntry struct {
	ID             string `json:"id"`
	TrackName      string `json:"trackName"`
	ArtistName     string `json:"artistName"`
	AlbumName      string `json:"albumName"`
	AlbumArtist    string `json:"albumArtist,omitempty"`
	FilePath       string `json:"filePath"`
	CoverURL       string `json:"coverUrl,omitempty"`
	CoverPath      string `json:"coverPath,omitempty"`
	ISRC           string `json:"isrc,omitempty"`
	Duration       int    `json:"duration,omitempty"`
	TrackNumber    int    `json:"trackNumber,omitempty"`
	TotalTracks    int    `json:"totalTracks,omitempty"`
	DiscNumber     int    `json:"discNumber,omitempty"`
	TotalDiscs     int    `json:"totalDiscs,omitempty"`
	ReleaseDate    string `json:"releaseDate,omitempty"`
	Genre          string `json:"genre,omitempty"`
	Composer       string `json:"composer,omitempty"`
	Label          string `json:"label,omitempty"`
	Copyright      string `json:"copyright,omitempty"`
	Quality        string `json:"quality,omitempty"`
	BitDepth       int    `json:"bitDepth,omitempty"`
	SampleRate     int    `json:"sampleRate,omitempty"`
	Bitrate        int    `json:"bitrate,omitempty"`
	SpotifyID      string `json:"spotifyId,omitempty"`
	DownloadedAt   string `json:"downloadedAt"`
	Service        string `json:"service,omitempty"`
	StorageMode    string `json:"storageMode,omitempty"`
	SAFFileName    string `json:"safFileName,omitempty"`
	SafRelativeDir string `json:"safRelativeDir,omitempty"`
	VideoFilePath  string `json:"videoFilePath,omitempty"`
	Format         string `json:"format,omitempty"`
}

type LibraryScanResult struct {
	ID          string
	TrackName   string
	ArtistName  string
	AlbumName   string
	AlbumArtist string
	FilePath    string
	CoverPath   string
	ScannedAt   string
	FileModTime int64
	ISRC        string
	TrackNumber int
	TotalTracks int
	DiscNumber  int
	TotalDiscs  int
	Duration    int
	ReleaseDate string
	BitDepth    int
	SampleRate  int
	Bitrate     int
	Genre       string
	Composer    string
	Label       string
	Copyright   string
	Format      string
}

type TrackKeyRequest struct {
	SpotifyID  string `json:"spotifyId,omitempty"`
	ISRC       string `json:"isrc,omitempty"`
	TrackName  string `json:"trackName,omitempty"`
	ArtistName string `json:"artistName,omitempty"`
}

type DownloadGroupedCounts struct {
	AlbumCount       int `json:"albumCount"`
	SingleTrackCount int `json:"singleTrackCount"`
}

type LocalLibraryAlbumGroup struct {
	AlbumName     string `json:"album_name"`
	ArtistName    string `json:"artist_name"`
	CoverPath     string `json:"cover_path,omitempty"`
	TrackCount    int    `json:"track_count"`
	LatestScanned string `json:"latest_scanned"`
}
