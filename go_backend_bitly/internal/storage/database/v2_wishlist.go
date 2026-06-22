package database

import (
	"fmt"
	"strings"
	"time"
)

// ============================================================
// V2: Wishlist Tracks
// ============================================================

// AddWishlistTrackV2 adds a track to the wishlist_tracks table.
func AddWishlistTrackV2(trackID, trackName, artistName, albumName, isrc, coverURL string, durationMs int) error {
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
		INSERT OR IGNORE INTO tracks (id, name, artist_id, isrc, duration_ms, cover_url, created_at)
		VALUES (?, ?, ?, ?, ?, ?, ?)
	`, canonID, trackName, artistID, isrc, durationMs, coverURL, now)
	if err != nil {
		return fmt.Errorf("ensure track record: %w", err)
	}

	_, err = db.Exec("INSERT OR IGNORE INTO wishlist_tracks (track_id, added_at) VALUES (?, ?)", canonID, now)
	if err != nil {
		return fmt.Errorf("add wishlist track: %w", err)
	}
	return nil
}
