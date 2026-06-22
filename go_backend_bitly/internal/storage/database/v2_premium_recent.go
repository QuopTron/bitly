package database

import (
	"encoding/json"
)

// GetRecentPlaysV2 returns play history ordered by most recent first.
func GetRecentPlaysV2(limit int) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	rows, err := db.Query(`SELECT track_id, track_name, artist_name, album_name, played_at, duration_ms
		FROM play_history ORDER BY played_at DESC LIMIT ?`, limit)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		var trackID, trackName, artistName, albumName, playedAt string
		var durationMs int64
		if err := rows.Scan(&trackID, &trackName, &artistName, &albumName, &playedAt, &durationMs); err == nil {
			results = append(results, map[string]interface{}{
				"trackId": trackID, "trackName": trackName, "artistName": artistName,
				"albumName": albumName, "playedAt": playedAt, "durationMs": durationMs,
			})
		}
	}
	if results == nil {
		results = []map[string]interface{}{}
	}
	out, _ := json.Marshal(results)
	return string(out), nil
}
