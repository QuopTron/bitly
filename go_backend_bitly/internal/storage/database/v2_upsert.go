package database

import (
	"crypto/md5"
	"database/sql"
	"encoding/hex"
	"fmt"
	"strings"
)

// ============================================================
// V2: Upsert canonical entities inside a transaction
// ============================================================

// UpsertV2Artist inserts or finds an artist by normalized_name. Returns the artist ID.
func UpsertV2Artist(tx *sql.Tx, name, provider, now string) (string, error) {
	normalized := strings.ToLower(strings.TrimSpace(name))
	if normalized == "" {
		return "", fmt.Errorf("empty artist name")
	}

	var existingID string
	err := tx.QueryRow("SELECT id FROM artists WHERE normalized_name = ?", normalized).Scan(&existingID)
	if err == nil {
		return existingID, nil
	}
	if err != sql.ErrNoRows {
		return "", fmt.Errorf("query artist: %w", err)
	}

	artistID := provider + ":" + normalized
	if provider == "" {
		hash := md5.Sum([]byte(normalized))
		artistID = "artist_" + hex.EncodeToString(hash[:8])
	}
	_, err = tx.Exec(`
		INSERT INTO artists (id, name, normalized_name, provider, created_at)
		VALUES (?, ?, ?, ?, ?)
	`, artistID, name, normalized, provider, now)
	if err != nil {
		return "", fmt.Errorf("insert artist: %w", err)
	}
	return artistID, nil
}

// UpsertV2Album inserts or finds an album. Returns the album ID.
func UpsertV2Album(tx *sql.Tx, name, artistID, provider, coverURL, coverPath, releaseDate string, totalTracks int, now string) (string, error) {
	normalized := strings.ToLower(strings.TrimSpace(name))
	if normalized == "" {
		return "", nil
	}

	var existingID string
	err := tx.QueryRow("SELECT id FROM albums WHERE artist_id = ? AND normalized_name = ?", artistID, normalized).Scan(&existingID)
	if err == nil {
		return existingID, nil
	}
	if err != sql.ErrNoRows {
		return "", fmt.Errorf("query album: %w", err)
	}

	albumID := artistID + ":" + normalized
	_, err = tx.Exec(`
		INSERT INTO albums (id, artist_id, name, normalized_name, cover_url, cover_path, release_date, total_tracks, provider, created_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`, albumID, artistID, name, normalized, coverURL, coverPath, releaseDate, totalTracks, provider, now)
	if err != nil {
		return "", fmt.Errorf("insert album: %w", err)
	}
	return albumID, nil
}

// UpsertV2Track inserts a track in the V2 tracks table only if it doesn't exist.
func UpsertV2Track(tx *sql.Tx, entry DownloadHistoryEntry, artistID, albumID, now string) (string, error) {
	canonID := CanonicalTrackID(entry.ISRC, entry.TrackName, entry.ArtistName)

	var existingID string
	err := tx.QueryRow("SELECT id FROM tracks WHERE id = ?", canonID).Scan(&existingID)
	if err == nil && existingID != "" {
		return canonID, nil
	}

	_, err = tx.Exec(`
		INSERT INTO tracks (
			id, name, artist_id, album_id, isrc, duration_ms, track_number, total_tracks,
			disc_number, total_discs, release_date, genre, composer, label, copyright,
			cover_url, cover_path, spotify_id, created_at
		) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
	`, canonID, entry.TrackName, artistID, albumID,
		entry.ISRC, entry.Duration, entry.TrackNumber, entry.TotalTracks,
		entry.DiscNumber, entry.TotalDiscs, entry.ReleaseDate,
		entry.Genre, entry.Composer, entry.Label, entry.Copyright,
		entry.CoverURL, entry.CoverPath, entry.SpotifyID, now)
	if err != nil {
		return "", fmt.Errorf("insert track: %w", err)
	}
	return canonID, nil
}

// UpsertV2Source inserts or updates a V2 source entry.
func UpsertV2Source(tx *sql.Tx, trackID, entryID, provider, externalID string, now string) error {
	sourceID := entryID
	if sourceID == "" {
		sourceID = trackID + ":" + provider
	}
	_, err := tx.Exec(`
		INSERT INTO sources (id, track_id, provider, external_id, created_at)
		VALUES (?, ?, ?, ?, ?)
		ON CONFLICT(track_id, provider) DO UPDATE SET
			external_id=excluded.external_id
	`, sourceID, trackID, provider, externalID, now)
	if err != nil {
		return fmt.Errorf("upsert source: %w", err)
	}
	return nil
}

// UpsertV2FileLink updates the files table's track_id to point to the canonical track.
func UpsertV2FileLink(tx *sql.Tx, entryID, canonID string) error {
	_, err := tx.Exec("UPDATE files SET track_id = ? WHERE id = ? AND source = 'download'", canonID, entryID)
	return err
}
