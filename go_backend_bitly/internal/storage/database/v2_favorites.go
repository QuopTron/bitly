package database

import (
	"database/sql"
	"fmt"
	"strings"
	"time"
)

// ============================================================
// V2: Loved Tracks
// ============================================================

// AddLovedTrackV2 adds a track to the loved_tracks table.
func AddLovedTrackV2(trackID, trackName, artistName, albumName, isrc, coverURL, spotifyID string, durationMs, trackNum int, coverPath string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	now := time.Now().UTC().Format(time.RFC3339)

	if trackName == "" {
		trackName = "Unknown Track"
	}
	if artistName == "" {
		artistName = "Unknown Artist"
	}

	canonID := CanonicalTrackID(isrc, trackName, artistName)
	normalized := strings.ToLower(strings.TrimSpace(artistName))

	artistID, err := resolveArtistID(db, normalized, artistName, now)
	if err != nil {
		return fmt.Errorf("resolve artist: %w", err)
	}

	_, err = db.Exec(`
		INSERT OR IGNORE INTO tracks (id, name, artist_id, isrc, duration_ms, track_number, cover_path, created_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)
	`, canonID, trackName, artistID, isrc, durationMs, trackNum, coverPath, now)
	if err != nil {
		return fmt.Errorf("ensure track record: %w", err)
	}

	_, err = db.Exec("INSERT OR IGNORE INTO loved_tracks (track_id, added_at) VALUES (?, ?)", canonID, now)
	if err != nil {
		return fmt.Errorf("add loved track: %w", err)
	}
	return nil
}

// resolveArtistID looks up or creates a minimal artist record.
func resolveArtistID(db *sql.DB, normalized, name, now string) (string, error) {
	var existingID string
	err := db.QueryRow("SELECT id FROM artists WHERE normalized_name = ?", normalized).Scan(&existingID)
	if err == nil {
		return existingID, nil
	}
	if err != sql.ErrNoRows {
		return "", err
	}
	artistID := "standalone:" + normalized
	if normalized == "" {
		artistID = "standalone:unknown"
	}
	_, err = db.Exec(`
		INSERT INTO artists (id, name, normalized_name, provider, created_at)
		VALUES (?, ?, ?, '', ?)
	`, artistID, name, normalized, now)
	if err != nil {
		return "", err
	}
	return artistID, nil
}
