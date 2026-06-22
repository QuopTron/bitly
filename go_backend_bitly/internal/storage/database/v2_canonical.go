package database

import (
	"crypto/md5"
	"database/sql"
	"encoding/hex"
	"strings"
)

// ============================================================
// Canonical Track Identity
// ============================================================

// CanonicalTrackID generates a deterministic canonical track ID.
// With ISRC: "canon_isrc_{lowercase_isrc}"
// Without ISRC: "canon_name_{md5(name|artist)}"
func CanonicalTrackID(isrc, trackName, artistName string) string {
	if isrc != "" {
		return "canon_isrc_" + strings.ToLower(isrc)
	}
	hash := md5.Sum([]byte(strings.ToLower(trackName + "|" + artistName)))
	return "canon_name_" + hex.EncodeToString(hash[:])
}

// FindCanonicalTrackV2 searches for an existing canonical track by ISRC first,
// then by track name + artist name. Returns the track ID if found, or empty string.
func FindCanonicalTrackV2(isrc, trackName, artistName string) string {
	db, err := Get()
	if err != nil {
		Log("[V2] FindCanonicalTrackV2: DB not available: %v", err)
		return ""
	}
	return findCanonicalTrackV2WithDB(db, isrc, trackName, artistName)
}

func findCanonicalTrackV2WithDB(db *sql.DB, isrc, trackName, artistName string) string {
	if isrc != "" {
		var id string
		err := db.QueryRow("SELECT id FROM tracks WHERE isrc = ?", isrc).Scan(&id)
		if err == nil && id != "" {
			return id
		}
	}
	if trackName != "" && artistName != "" {
		var id string
		err := db.QueryRow(`
			SELECT t.id FROM tracks t
			JOIN artists a ON t.artist_id = a.id
			WHERE LOWER(t.name) = LOWER(?) AND LOWER(a.name) = LOWER(?)
			LIMIT 1
		`, trackName, artistName).Scan(&id)
		if err == nil && id != "" {
			return id
		}
	}
	return ""
}

// ResolveTrackID maps an entry ID (from downloads or metadata) to a canonical track ID.
func ResolveTrackID(entryID string) string {
	db, err := Get()
	if err != nil {
		Log("[V2] ResolveTrackID: DB not available: %v", err)
		return entryID
	}

	var exists int
	err = db.QueryRow("SELECT COUNT(*) FROM tracks WHERE id = ?", entryID).Scan(&exists)
	if err == nil && exists > 0 {
		return entryID
	}

	var isrc, trackName, artistName string
	err = db.QueryRow(
		"SELECT COALESCE(isrc,''), COALESCE(track_name,''), COALESCE(artist_name,'') FROM metadata WHERE id = ?",
		entryID).Scan(&isrc, &trackName, &artistName)
	if err == nil && trackName != "" {
		if canonID := findCanonicalTrackV2WithDB(db, isrc, trackName, artistName); canonID != "" {
			return canonID
		}
	}

	err = db.QueryRow("SELECT COUNT(*) FROM tracks WHERE id = ?", entryID).Scan(&exists)
	if err == nil && exists > 0 {
		return entryID
	}

	return entryID
}
