package database

import (
	"encoding/json"
)

// GetCollectionTracksV2 returns all tracks in a collection as JSON.
func GetCollectionTracksV2(collectionID string) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}

	rows, err := db.Query(`
		SELECT ci.track_id, ci.added_at,
			COALESCE(t.name, '') as track_name,
			COALESCE(a.name, '') as artist_name,
			COALESCE(al.name, '') as album_name,
			COALESCE(t.isrc, '') as isrc,
			COALESCE(t.duration_ms, 0) as duration_ms,
			COALESCE(t.cover_url, '') as cover_url,
			COALESCE(t.cover_path, '') as cover_path,
			COALESCE(t.lyrics_path, '') as lyrics_path,
			COALESCE(t.video_path, '') as video_path,
			COALESCE(f.file_path, '') as file_path
		FROM collection_items ci
		LEFT JOIN tracks t ON ci.track_id = t.id
		LEFT JOIN artists a ON t.artist_id = a.id
		LEFT JOIN albums al ON t.album_id = al.id
		LEFT JOIN files f ON f.track_id = t.id AND f.source = 'download'
		WHERE ci.collection_id = ?
		ORDER BY ci.position, ci.added_at
	`, collectionID)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		var trackID, addedAt, trackName, artistName, albumName string
		var isrc, coverURL, coverPath, lyricsPath, videoPath, filePath string
		var durationMs int64
		if err := rows.Scan(&trackID, &addedAt, &trackName, &artistName, &albumName,
			&isrc, &durationMs, &coverURL, &coverPath, &lyricsPath, &videoPath, &filePath); err == nil {
			results = append(results, map[string]interface{}{
				"trackId":    trackID,
				"trackName":  trackName,
				"artistName": artistName,
				"albumName":  albumName,
				"isrc":       isrc,
				"durationMs": durationMs,
				"coverUrl":   coverURL,
				"coverPath":  coverPath,
				"lyricsPath": lyricsPath,
				"videoPath":  videoPath,
				"filePath":   filePath,
				"addedAt":    addedAt,
			})
		}
	}
	if results == nil {
		results = []map[string]interface{}{}
	}
	out, _ := json.Marshal(results)
	return string(out), nil
}

// GetFavoritePlaylistsV2 returns all collections of type "playlist" as JSON.
func GetFavoritePlaylistsV2() (string, error) {
	db, err := Get()
	if err != nil {
		return "[]", nil
	}

	rows, err := db.Query(`
		SELECT c.id, c.name, c.type, COALESCE(c.cover_path,''),
			COALESCE(c.created_at,'') as created_at,
			COALESCE(c.updated_at,'') as updated_at,
			(SELECT COUNT(*) FROM collection_items ci WHERE ci.collection_id = c.id) as item_count
		FROM collections c
		WHERE c.type = 'playlist'
		ORDER BY c.updated_at DESC
	`)
	if err != nil {
		Log("[V2] GetFavoritePlaylistsV2 query failed: %v", err)
		return "[]", nil
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		var id, name, collectionType, coverPath, createdAt, updatedAt string
		var itemCount int
		if err := rows.Scan(&id, &name, &collectionType, &coverPath, &createdAt, &updatedAt, &itemCount); err == nil {
			results = append(results, map[string]interface{}{
				"id":        id,
				"name":      name,
				"type":      collectionType,
				"coverPath": coverPath,
				"createdAt": createdAt,
				"updatedAt": updatedAt,
				"itemCount": itemCount,
			})
		}
	}
	if results == nil {
		results = []map[string]interface{}{}
	}
	out, _ := json.Marshal(results)
	return string(out), nil
}
