package database

import (
	"encoding/json"
	"time"
)

// ============================================================
// V2: Download tracking
// ============================================================

// LogDownloadV2 records a download event.
func LogDownloadV2(trackID, albumID, fileID, source string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	now := time.Now().UTC().Format(time.RFC3339)
	if source == "" {
		source = "download"
	}
	_, err = db.Exec(`INSERT INTO download_history_log (track_id, album_id, file_id, downloaded_at, source)
		VALUES (?, ?, ?, ?, ?)`, trackID, albumID, fileID, now, source)
	return err
}

// GetDownloadedTracksV2 returns all downloaded tracks as JSON.
func GetDownloadedTracksV2() (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	rows, err := db.Query(`
		SELECT COALESCE(t.id, f.metadata_id, '') as track_id,
			COALESCE(t.name, m.track_name, '') as track_name,
			COALESCE(m.artist_name, '') as artist_name,
			COALESCE(m.album_name, '') as album_name,
			f.file_path, COALESCE(f.format,''),
			COALESCE(f.downloaded_at, '') as downloaded_at
		FROM files f
		LEFT JOIN metadata m ON m.id = f.metadata_id
		LEFT JOIN tracks t ON t.id = f.track_id
		WHERE f.source IN ('download', 'local_scan')
		ORDER BY COALESCE(f.downloaded_at, '') DESC
	`)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		var trackID, trackName, artistName, albumName, filePath, format string
		var downloadedAt string
		if err := rows.Scan(&trackID, &trackName, &artistName, &albumName, &filePath, &format, &downloadedAt); err == nil {
			results = append(results, map[string]interface{}{
				"trackId":      trackID,
				"trackName":    trackName,
				"artistName":   artistName,
				"albumName":    albumName,
				"filePath":     filePath,
				"format":       format,
				"downloadedAt": downloadedAt,
			})
		}
	}
	if results == nil {
		results = []map[string]interface{}{}
	}
	out, _ := json.Marshal(results)
	return string(out), nil
}

// GetDownloadedAlbumsV2 returns downloaded albums as JSON.
func GetDownloadedAlbumsV2() (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	rows, err := db.Query(`
		SELECT COALESCE(al.id, ''),
			COALESCE(al.name, m.album_name, ''),
			COALESCE(ar.name, m.artist_name, ''),
			COALESCE(al.cover_url, ''),
			COALESCE(al.cover_path, ''),
			COUNT(f.id) as downloaded_tracks
		FROM files f
		LEFT JOIN metadata m ON m.id = f.metadata_id
		LEFT JOIN tracks t ON t.id = f.track_id
		LEFT JOIN albums al ON al.id = t.album_id
		LEFT JOIN artists ar ON ar.id = al.artist_id
		WHERE f.source IN ('download', 'local_scan') AND m.album_name IS NOT NULL AND m.album_name != ''
		GROUP BY COALESCE(al.id, m.album_name)
		ORDER BY MAX(COALESCE(f.downloaded_at, '')) DESC
	`)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		var albumID, albumName, artistName, coverURL, coverPath string
		var downloadedTracks int64
		if err := rows.Scan(&albumID, &albumName, &artistName, &coverURL, &coverPath, &downloadedTracks); err == nil {
			results = append(results, map[string]interface{}{
				"albumId":          albumID,
				"albumName":        albumName,
				"artistName":       artistName,
				"coverUrl":         coverURL,
				"coverPath":        coverPath,
				"downloadedTracks": downloadedTracks,
			})
		}
	}
	if results == nil {
		results = []map[string]interface{}{}
	}
	out, _ := json.Marshal(results)
	return string(out), nil
}
