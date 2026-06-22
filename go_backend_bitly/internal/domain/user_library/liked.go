package userlibrary

import (
	"database/sql"
	"encoding/json"
	"time"
)

// LikedService manages liked tracks.
type LikedService struct {
	db *sql.DB
}

// NewLikedService creates a new liked service.
func NewLikedService(db *sql.DB) *LikedService {
	return &LikedService{db: db}
}

// AddLike adds a track to the user's liked tracks.
func (s *LikedService) AddLike(userID, trackID string, attribution SourceAttribution) error {
	attrJSON, _ := json.Marshal(attribution)
	_, err := s.db.Exec(`
		INSERT INTO user_liked_tracks (user_id, track_id, liked_at, source_attribution)
		VALUES (?, ?, ?, ?)
		ON CONFLICT(user_id, track_id) DO UPDATE SET liked_at=excluded.liked_at
	`, userID, trackID, time.Now().UTC().Format(time.RFC3339), string(attrJSON))
	return err
}

// RemoveLike removes a liked track.
func (s *LikedService) RemoveLike(userID, trackID string) error {
	_, err := s.db.Exec(`DELETE FROM user_liked_tracks WHERE user_id = ? AND track_id = ?`, userID, trackID)
	return err
}

// IsLiked checks if a track is liked by the user.
func (s *LikedService) IsLiked(userID, trackID string) bool {
	var count int
	err := s.db.QueryRow(`SELECT COUNT(*) FROM user_liked_tracks WHERE user_id = ? AND track_id = ?`, userID, trackID).Scan(&count)
	return err == nil && count > 0
}

// DownloadedService manages downloaded tracks.
type DownloadedService struct {
	db *sql.DB
}

// NewDownloadedService creates a new downloaded service.
func NewDownloadedService(db *sql.DB) *DownloadedService {
	return &DownloadedService{db: db}
}

// SaveDownload records a completed download.
func (s *DownloadedService) SaveDownload(dt *DownloadedTrack) error {
	metaJSON, _ := json.Marshal(dt.MetadataSources)
	_, err := s.db.Exec(`
		INSERT INTO user_downloaded_files (user_id, track_id, source_provider, source_track_id, metadata_sources, file_type, file_path, quality, file_size_bytes, downloaded_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`, dt.UserID, dt.TrackID, dt.SourceProvider, dt.SourceTrackID, string(metaJSON),
		"audio", dt.AudioFile.Path, dt.AudioFile.Quality, dt.AudioFile.SizeBytes,
		dt.DownloadedAt.Format(time.RFC3339))
	return err
}

// GetDownloadedTracks lists all downloaded tracks for a user.
func (s *DownloadedService) GetDownloadedTracks(userID string) ([]DownloadedTrack, error) {
	rows, err := s.db.Query(`
		SELECT user_id, track_id, source_provider, COALESCE(source_track_id,''), file_path, COALESCE(quality,''), COALESCE(file_size_bytes,0), downloaded_at
		FROM user_downloaded_files WHERE user_id = ? ORDER BY downloaded_at DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var tracks []DownloadedTrack
	for rows.Next() {
		var dt DownloadedTrack
		var downloadedAt string
		if err := rows.Scan(&dt.UserID, &dt.TrackID, &dt.SourceProvider, &dt.SourceTrackID,
			&dt.AudioFile.Path, &dt.AudioFile.Quality, &dt.AudioFile.SizeBytes, &downloadedAt); err != nil {
			return nil, err
		}
		dt.DownloadedAt, _ = time.Parse(time.RFC3339, downloadedAt)
		tracks = append(tracks, dt)
	}
	return tracks, nil
}
