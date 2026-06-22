package database

import (
	"database/sql"
	"time"
)

func IncrementPlayCount(itemID, itemType string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	_, err = db.Exec(`
		INSERT INTO play_aggregates (item_id, type, play_count, last_played_at)
		VALUES (?, ?, 1, ?)
		ON CONFLICT(item_id) DO UPDATE SET
			play_count = play_count + 1,
			last_played_at = excluded.last_played_at`,
		itemID, itemType, time.Now().UTC().Format(time.RFC3339))
	return err
}

func GetPlayAggregates(itemType string) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	var rows *sql.Rows
	if itemType != "" {
		rows, err = db.Query("SELECT * FROM play_aggregates WHERE type = ? ORDER BY play_count DESC", itemType)
	} else {
		rows, err = db.Query("SELECT * FROM play_aggregates ORDER BY play_count DESC")
	}
	if err != nil {
		return "", err
	}
	defer rows.Close()
	return rowsToJSON(rows), nil
}
