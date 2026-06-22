package userlibrary

import (
	"database/sql"
	"time"
)

// PlayHistoryEntry represents a single play event.
type PlayHistoryEntry struct {
	ID              int64     `json:"id"`
	UserID          string    `json:"user_id"`
	TrackID         string    `json:"track_id"`
	TrackName       string    `json:"track_name,omitempty"`
	ArtistName      string    `json:"artist_name,omitempty"`
	PlayedAt        time.Time `json:"played_at"`
	DurationPlayedMs int64    `json:"duration_played_ms"`
	DurationTotalMs int64     `json:"duration_total_ms"`
	Source          string    `json:"source"`
}

// HistoryService manages play history.
type HistoryService struct {
	db *sql.DB
}

// NewHistoryService creates a new history service.
func NewHistoryService(db *sql.DB) *HistoryService {
	return &HistoryService{db: db}
}

// LogPlay records a play event.
func (s *HistoryService) LogPlay(entry PlayHistoryEntry) error {
	_, err := s.db.Exec(`
		INSERT INTO playback_history (user_id, track_id, played_at, duration_played_ms, source)
		VALUES (?, ?, ?, ?, ?)
	`, entry.UserID, entry.TrackID, entry.PlayedAt.Format(time.RFC3339), entry.DurationPlayedMs, entry.Source)
	return err
}

// GetRecentPlays returns the most recent plays for a user.
func (s *HistoryService) GetRecentPlays(userID string, limit int) ([]PlayHistoryEntry, error) {
	rows, err := s.db.Query(`
		SELECT id, user_id, COALESCE(track_id,''), played_at, COALESCE(duration_played_ms,0), COALESCE(source,'')
		FROM playback_history WHERE user_id = ? ORDER BY played_at DESC LIMIT ?
	`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var entries []PlayHistoryEntry
	for rows.Next() {
		var e PlayHistoryEntry
		var playedAtStr string
		if err := rows.Scan(&e.ID, &e.UserID, &e.TrackID, &playedAtStr, &e.DurationPlayedMs, &e.Source); err != nil {
			return nil, err
		}
		e.PlayedAt, _ = time.Parse(time.RFC3339, playedAtStr)
		entries = append(entries, e)
	}
	return entries, nil
}

// GetPlayCount returns the total play count for a track.
func (s *HistoryService) GetPlayCount(trackID string) (int, error) {
	var count int
	err := s.db.QueryRow(`SELECT COUNT(*) FROM playback_history WHERE track_id = ?`, trackID).Scan(&count)
	return count, err
}

// GetTotalListeningTime returns total listening time in ms for a user.
func (s *HistoryService) GetTotalListeningTime(userID string) (int64, error) {
	var total int64
	err := s.db.QueryRow(`SELECT COALESCE(SUM(duration_played_ms), 0) FROM playback_history WHERE user_id = ?`, userID).Scan(&total)
	return total, err
}
