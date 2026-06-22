package database

import (
	"database/sql"
	"encoding/json"
)

func GetDownloadHistory(limit, offset int) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	rows, err := db.Query(`
		SELECT `+historyColumns()+`
		FROM metadata m JOIN files f ON m.id = f.metadata_id
		WHERE f.source = 'download'
		ORDER BY f.downloaded_at DESC
		LIMIT ? OFFSET ?`, limit, offset)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var entries []DownloadHistoryEntry
	for rows.Next() {
		e, err := scanHistoryEntry(rows)
		if err == nil {
			entries = append(entries, e)
		}
	}
	if entries == nil {
		entries = []DownloadHistoryEntry{}
	}
	out, _ := json.Marshal(entries)
	return string(out), nil
}

func GetDownloadHistoryCount() (int, error) {
	db, err := Get()
	if err != nil {
		return 0, err
	}
	var count int
	err = db.QueryRow("SELECT COUNT(*) FROM files WHERE source = 'download'").Scan(&count)
	return count, err
}

func GetDownloadHistoryGroupedCounts() (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	rows, err := db.Query(`
		SELECT m.album_name, m.album_artist, COUNT(*) as cnt
		FROM metadata m JOIN files f ON m.id = f.metadata_id
		WHERE f.source = 'download'
		GROUP BY m.album_name, m.album_artist`)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var counts DownloadGroupedCounts
	for rows.Next() {
		var album, artist sql.NullString
		var cnt int
		if err := rows.Scan(&album, &artist, &cnt); err == nil {
			if album.Valid && album.String != "" {
				counts.AlbumCount++
			} else {
				counts.SingleTrackCount++
			}
		}
	}
	out, _ := json.Marshal(counts)
	return string(out), nil
}
