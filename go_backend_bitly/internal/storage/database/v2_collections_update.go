package database

import (
	"fmt"
	"time"
)

// UpdateCollectionV2 updates a collection's name and cover.
func UpdateCollectionV2(id, name, coverPath string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	now := time.Now().UTC().Format(time.RFC3339)
	_, err = db.Exec(`
		UPDATE collections SET name = ?, cover_path = COALESCE(NULLIF(?, ''), cover_path), updated_at = ?
		WHERE id = ?
	`, name, coverPath, now, id)
	return err
}

// ReorderCollectionItemsV2 reorders items in a collection.
func ReorderCollectionItemsV2(collectionID string, itemIDs []string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	now := time.Now().UTC().Format(time.RFC3339)
	for pos, id := range itemIDs {
		_, err := db.Exec("UPDATE collection_items SET position = ? WHERE collection_id = ? AND item_id = ?", pos, collectionID, id)
		if err != nil {
			return fmt.Errorf("reorder item %s: %w", id, err)
		}
	}
	db.Exec("UPDATE collections SET updated_at = ? WHERE id = ?", now, collectionID)
	return nil
}

// DeleteCollectionV2 deletes a collection and its items.
func DeleteCollectionV2(id string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	_, err = db.Exec("DELETE FROM collection_items WHERE collection_id = ?", id)
	if err != nil {
		return fmt.Errorf("delete collection items: %w", err)
	}
	_, err = db.Exec("DELETE FROM collections WHERE id = ?", id)
	return err
}
