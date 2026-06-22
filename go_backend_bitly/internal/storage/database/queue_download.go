package database

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"time"
)

func SaveDownloadQueue(itemsJSON string) error {
	var items []map[string]interface{}
	if err := json.Unmarshal([]byte(itemsJSON), &items); err != nil {
		return err
	}
	return WithTx(func(tx *sql.Tx) error {
		if _, err := tx.Exec("DELETE FROM download_queue"); err != nil {
			return fmt.Errorf("clear download_queue: %w", err)
		}
		now := time.Now().UTC().Format(time.RFC3339)
		for _, item := range items {
			id, _ := item["id"].(string)
			trackJSON, _ := item["track_json"].(string)
			itemJSON, _ := item["item_json"].(string)
			status, _ := item["status"].(string)
			if status == "" {
				status = "pending"
			}
			progress := 0.0
			if p, ok := item["progress"].(float64); ok {
				progress = p
			}
			_, err := tx.Exec(`
				INSERT INTO download_queue (id, track_json, item_json, status, progress, created_at, updated_at, added_at)
				VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
				id, trackJSON, itemJSON, status, progress, now, now, now)
			if err != nil {
				return err
			}
		}
		return nil
	})
}

func LoadDownloadQueue() (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT * FROM download_queue ORDER BY added_at ASC")
	if err != nil {
		return "", err
	}
	defer rows.Close()
	return rowsToJSON(rows), nil
}

func GetPendingDownloadQueueRows() (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT * FROM download_queue WHERE status = 'pending' ORDER BY added_at ASC")
	if err != nil {
		return "", err
	}
	defer rows.Close()
	return rowsToJSON(rows), nil
}

func GetPendingDownloadQueueRowsJSON() (string, error) {
	return GetPendingDownloadQueueRows()
}

func ReplacePendingDownloadQueueRows(rowsJSON string) error {
	var rows []map[string]interface{}
	if err := json.Unmarshal([]byte(rowsJSON), &rows); err != nil {
		return err
	}
	return WithTx(func(tx *sql.Tx) error {
		_, _ = tx.Exec("DELETE FROM download_queue WHERE status = 'pending'")
		now := time.Now().UTC().Format(time.RFC3339)
		for _, item := range rows {
			id, _ := item["id"].(string)
			trackJSON, _ := item["track_json"].(string)
			itemJSON, _ := item["item_json"].(string)
			_, err := tx.Exec(`
				INSERT INTO download_queue (id, track_json, item_json, status, progress, created_at, updated_at, added_at)
				VALUES (?, ?, ?, 'pending', 0, ?, ?, ?)`,
				id, trackJSON, itemJSON, now, now, now)
			if err != nil {
				return err
			}
		}
		return nil
	})
}
