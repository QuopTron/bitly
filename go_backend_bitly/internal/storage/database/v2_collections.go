package database

import (
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"time"
)

// ============================================================
// V2: Collections (Playlists)
// ============================================================

// CreateCollectionV2 creates a new collection and returns its ID.
func CreateCollectionV2(name, collectionType, coverPath string) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	now := time.Now().UTC().Format(time.RFC3339)
	hash := md5.Sum([]byte(name + now))
	id := "coll_" + hex.EncodeToString(hash[:8])

	if collectionType == "" {
		collectionType = "playlist"
	}

	_, err = db.Exec(`
		INSERT INTO collections (id, name, type, cover_path, created_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?)
	`, id, name, collectionType, coverPath, now, now)
	if err != nil {
		return "", fmt.Errorf("create collection: %w", err)
	}
	return id, nil
}

// AddCollectionTrackV2 adds a track to a collection.
func AddCollectionTrackV2(collectionID, trackID string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	now := time.Now().UTC().Format(time.RFC3339)

	_, err = db.Exec(`
		INSERT INTO collection_items (collection_id, item_id, track_id, added_at)
		VALUES (?, ?, ?, ?)
		ON CONFLICT(collection_id, item_id) DO UPDATE SET
			track_id=excluded.track_id, added_at=excluded.added_at
	`, collectionID, trackID, trackID, now)
	if err != nil {
		return fmt.Errorf("add collection track: %w", err)
	}

	db.Exec("UPDATE collections SET updated_at = ? WHERE id = ?", now, collectionID)
	return nil
}

// RemoveCollectionTrackV2 removes a track from a collection.
func RemoveCollectionTrackV2(collectionID, trackID string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	_, err = db.Exec("DELETE FROM collection_items WHERE collection_id = ? AND (item_id = ? OR track_id = ?)", collectionID, trackID, trackID)
	if err != nil {
		return fmt.Errorf("remove collection track: %w", err)
	}

	now := time.Now().UTC().Format(time.RFC3339)
	db.Exec("UPDATE collections SET updated_at = ? WHERE id = ?", now, collectionID)
	return nil
}
