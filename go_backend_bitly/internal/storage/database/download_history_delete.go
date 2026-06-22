package database

import (
	"database/sql"
	"encoding/json"
	"fmt"
)

func ClearDownloadHistory() error {
	db, err := Get()
	if err != nil {
		return err
	}
	_, err = db.Exec("DELETE FROM files WHERE source = 'download'")
	return err
}

func DeleteDownloadEntriesByIDs(ids []string) error {
	return WithTx(func(tx *sql.Tx) error {
		for _, id := range ids {
			tx.Exec("DELETE FROM files WHERE id = ? AND source = 'download'", id)
			tx.Exec("DELETE FROM metadata WHERE id = ?", id)
		}
		return nil
	})
}

func DeleteDownloadEntriesByIDsJSON(requestJSON string) error {
	var ids []string
	if err := json.Unmarshal([]byte(requestJSON), &ids); err != nil {
		return fmt.Errorf("invalid ids JSON: %w", err)
	}
	return DeleteDownloadEntriesByIDs(ids)
}

func DeleteDownloadEntriesByPaths(paths []string) error {
	return WithTx(func(tx *sql.Tx) error {
		for _, path := range paths {
			tx.Exec("DELETE FROM files WHERE file_path = ? AND source = 'download'", path)
		}
		return nil
	})
}

func DeleteDownloadEntriesByTrackMatch(trackName, artistName string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	rows, err := db.Query(
		"SELECT id FROM metadata WHERE LOWER(track_name) = LOWER(?) AND LOWER(artist_name) = LOWER(?)",
		trackName, artistName)
	if err != nil {
		return err
	}
	defer rows.Close()

	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err == nil {
			ids = append(ids, id)
		}
	}
	if len(ids) == 0 {
		return nil
	}
	return DeleteDownloadEntriesByIDs(ids)
}
