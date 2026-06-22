package userlibrary

import (
	"time"
)

// SourceAttribution tracks where each piece of metadata came from.
type SourceAttribution struct {
	Title       string `json:"title"`
	Artist      string `json:"artist"`
	Album       string `json:"album"`
	Duration    string `json:"duration"`
	ISRC        string `json:"isrc"`
	Genre       string `json:"genre"`
	Label       string `json:"label"`
	Year        string `json:"year"`
	Cover       string `json:"cover"`
	Lyrics      string `json:"lyrics"`
	AlbumArtist string `json:"album_artist"`
	ReleaseDate string `json:"release_date"`
}

// DownloadedFile represents a downloaded file on disk.
type DownloadedFile struct {
	Path      string `json:"path"`
	SizeBytes int64  `json:"size_bytes"`
	Quality   string `json:"quality"`
	Format    string `json:"format"`
	Source    string `json:"source"`
}

// LikedTrack represents a track liked by the user (metadata only, no files).
type LikedTrack struct {
	UserID             string            `json:"user_id"`
	TrackID            string            `json:"track_id"`
	LikedAt            time.Time         `json:"liked_at"`
	SourceAttribution SourceAttribution `json:"source_attribution"`
}

// DownloadedTrack represents a fully downloaded track with all its files.
type DownloadedTrack struct {
	UserID           string            `json:"user_id"`
	TrackID          string            `json:"track_id"`
	SourceProvider   string            `json:"source_provider"`
	SourceTrackID    string            `json:"source_track_id"`
	MetadataSources  SourceAttribution `json:"metadata_sources"`
	AudioFile        DownloadedFile    `json:"audio_file"`
	CoverFile        DownloadedFile    `json:"cover_file"`
	LyricsFile       *DownloadedFile   `json:"lyrics_file,omitempty"`
	VideoFile        *DownloadedFile   `json:"video_file,omitempty"`
	DownloadedAt     time.Time         `json:"downloaded_at"`
}
