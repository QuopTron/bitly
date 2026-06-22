package database

import "encoding/json"

func GetHiddenRecentDownloadIds() (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT download_id FROM hidden_download_ids")
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err == nil {
			ids = append(ids, id)
		}
	}
	if ids == nil {
		ids = []string{}
	}
	out, _ := json.Marshal(ids)
	return string(out), nil
}

func AddHiddenRecentDownloadId(downloadID string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	_, err = db.Exec("INSERT OR IGNORE INTO hidden_download_ids (download_id) VALUES (?)", downloadID)
	return err
}

func ClearHiddenRecentDownloadIds() error {
	db, err := Get()
	if err != nil {
		return err
	}
	_, err = db.Exec("DELETE FROM hidden_download_ids")
	return err
}
