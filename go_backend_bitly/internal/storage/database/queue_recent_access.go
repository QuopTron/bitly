package database

import "time"

func UpsertRecentAccessRow(key, itemJSON, accessedAt string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	if accessedAt == "" {
		accessedAt = time.Now().UTC().Format(time.RFC3339)
	}
	_, err = db.Exec(`
		INSERT INTO recent_access (id, item_json, type, accessed_at)
		VALUES (?, ?, 'recent', ?)
		ON CONFLICT(id) DO UPDATE SET item_json=excluded.item_json, accessed_at=excluded.accessed_at`,
		key, itemJSON, accessedAt)
	return err
}

func GetRecentAccessRows(limit int) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT id AS key, item_json AS json, accessed_at FROM recent_access ORDER BY accessed_at DESC LIMIT ?", limit)
	if err != nil {
		return "", err
	}
	defer rows.Close()
	return rowsToJSON(rows), nil
}

func DeleteRecentAccessRow(key string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	_, err = db.Exec("DELETE FROM recent_access WHERE id = ?", key)
	return err
}

func ClearRecentAccessRows() error {
	db, err := Get()
	if err != nil {
		return err
	}
	_, err = db.Exec("DELETE FROM recent_access")
	return err
}
