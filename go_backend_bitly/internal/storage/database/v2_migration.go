package database

import (
	"database/sql"
)

// ============================================================
// V2: Migration — ensure tables and additional columns
// ============================================================

// RunMigrationV2 ensures all V2 columns exist on legacy tables and creates indexes.
func RunMigrationV2(db *sql.DB) error {
	Log("[DB] Running V2 migration...")

	tables := []struct {
		name    string
		colDef string
	}{
		{"play_history", "TEXT REFERENCES tracks(id) ON DELETE SET NULL"},
		{"sources", "TEXT NOT NULL REFERENCES tracks(id) ON DELETE CASCADE"},
		{"files", "TEXT REFERENCES tracks(id) ON DELETE CASCADE"},
	}
	for _, table := range tables {
		rows, err := db.Query("PRAGMA table_info(" + table.name + ")")
		if err != nil {
			Log("[DB]  PRAGMA check for %s failed: %v", table.name, err)
			continue
		}
		hasCol := false
		for rows.Next() {
			var cid int
			var name, colType string
			var notNull, pk int
			var defVal sql.NullString
			if err := rows.Scan(&cid, &name, &colType, &notNull, &defVal, &pk); err == nil && name == "track_id" {
				hasCol = true
				break
			}
		}
		rows.Close()

		if !hasCol {
			Log("[DB]  Adding track_id column to %s...", table.name)
			_, err := db.Exec("ALTER TABLE " + table.name + " ADD COLUMN track_id " + table.colDef)
			if err != nil {
				Log("[DB]  Failed to add track_id to %s: %v", table.name, err)
			}
		}
	}

	db.Exec("CREATE INDEX IF NOT EXISTS idx_sources_track_id ON sources(track_id)")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_play_history_track_id ON play_history(track_id)")
	db.Exec("CREATE INDEX IF NOT EXISTS idx_files_track_id ON files(track_id)")

	db.Exec(`INSERT OR IGNORE INTO user_premium (id, tier, premium_until, daily_play_limit, created_at, updated_at)
		VALUES ('default', 'free', 0, 50, datetime('now'), datetime('now'))`)

	Log("[DB] V2 migration complete.")
	return nil
}

// RunMigrationV2JSON is a gomobile-friendly alias that opens DB and runs migration.
func RunMigrationV2JSON() (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	if err := RunMigrationV2(db); err != nil {
		return "", err
	}
	return "ok", nil
}

// GetQueueCounts returns download queue counts (all, by status) as JSON.
func GetQueueCounts(searchQuery string) (string, error) {
	return GetDownloadHistoryGroupedCounts()
}

// FindExistingDownloadEntry checks if a download already exists for the given track identity.
func FindExistingDownloadEntry(spotifyID, isrc, trackName, artistName string) (string, error) {
	if spotifyID != "" {
		if entry, err := GetDownloadEntryBySpotifyID(spotifyID); err == nil && entry != "" && entry != "{}" {
			return entry, nil
		}
	}
	if isrc != "" {
		if entry, err := GetDownloadEntryByISRC(isrc); err == nil && entry != "" && entry != "{}" {
			return entry, nil
		}
	}
	if trackName != "" && artistName != "" {
		if entry, err := FindDownloadEntryByTrackAndArtist(trackName, artistName); err == nil && entry != "" && entry != "{}" {
			return entry, nil
		}
	}
	return "", nil
}
