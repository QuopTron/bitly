package database

import (
	"encoding/json"
)

// ============================================================
// V2: Artist Top Tracks & Top Albums
// ============================================================

// GetArtistTopTracksV2 returns top tracks for an artist.
func GetArtistTopTracksV2(artistID string, limit int) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	if limit <= 0 {
		limit = 20
	}
	rows, err := db.Query(`
		SELECT t.id, t.name, COALESCE(t.cover_url,'') as cover_url,
			COALESCE(t.cover_path,'') as cover_path,
			t.duration_ms, COALESCE(t.isrc,''),
			COALESCE(pa.play_count,0) as play_count
		FROM tracks t
		LEFT JOIN play_aggregates pa ON pa.item_id = t.id AND pa.type = 'track'
		WHERE t.artist_id = ?
		ORDER BY pa.play_count DESC, t.name ASC
		LIMIT ?
	`, artistID, limit)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		var id, name, coverURL, coverPath, isrc string
		var durationMs, playCount int64
		if err := rows.Scan(&id, &name, &coverURL, &coverPath, &durationMs, &isrc, &playCount); err == nil {
			results = append(results, map[string]interface{}{
				"trackId":   id,
				"name":      name,
				"coverUrl":  coverURL,
				"coverPath": coverPath,
				"durationMs": durationMs,
				"isrc":      isrc,
				"playCount": playCount,
			})
		}
	}
	if results == nil {
		results = []map[string]interface{}{}
	}
	out, _ := json.Marshal(results)
	return string(out), nil
}

// GetArtistTopAlbumsV2 returns top albums for an artist.
func GetArtistTopAlbumsV2(artistID string, limit int) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	if limit <= 0 {
		limit = 10
	}
	rows, err := db.Query(`
		SELECT al.id, al.name, COALESCE(al.cover_url,'') as cover_url,
			COALESCE(al.cover_path,'') as cover_path,
			COALESCE(al.release_date,''), al.total_tracks,
			COALESCE(pa.play_count,0) as play_count
		FROM albums al
		LEFT JOIN play_aggregates pa ON pa.item_id = al.id AND pa.type = 'album'
		WHERE al.artist_id = ?
		ORDER BY pa.play_count DESC, al.release_date DESC
		LIMIT ?
	`, artistID, limit)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		var id, name, coverURL, coverPath, releaseDate string
		var totalTracks, playCount int64
		if err := rows.Scan(&id, &name, &coverURL, &coverPath, &releaseDate, &totalTracks, &playCount); err == nil {
			results = append(results, map[string]interface{}{
				"albumId":     id,
				"name":        name,
				"coverUrl":    coverURL,
				"coverPath":   coverPath,
				"releaseDate": releaseDate,
				"totalTracks": totalTracks,
				"playCount":   playCount,
			})
		}
	}
	if results == nil {
		results = []map[string]interface{}{}
	}
	out, _ := json.Marshal(results)
	return string(out), nil
}
