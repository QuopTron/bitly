package database

import (
	"encoding/json"
)

// GetWishlistTracksV2 returns all wishlist tracks as JSON.
func GetWishlistTracksV2() (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}

	rows, err := db.Query(`
		SELECT wt.track_id, wt.added_at,
			COALESCE(t.name, '') as track_name,
			COALESCE(a.name, '') as artist_name,
			COALESCE(al.name, '') as album_name,
			COALESCE(t.isrc, '') as isrc,
			COALESCE(t.duration_ms, 0) as duration_ms,
			COALESCE(t.track_number, 0) as track_number,
			COALESCE(t.cover_url, '') as cover_url,
			COALESCE(t.cover_path, '') as cover_path,
			COALESCE(t.lyrics_path, '') as lyrics_path,
			COALESCE(t.video_path, '') as video_path,
			COALESCE(f.file_path, '') as file_path
		FROM wishlist_tracks wt
		JOIN tracks t ON wt.track_id = t.id
		LEFT JOIN artists a ON t.artist_id = a.id
		LEFT JOIN albums al ON t.album_id = al.id
		LEFT JOIN files f ON f.track_id = t.id AND f.source = 'download'
		ORDER BY wt.added_at DESC
	`)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		var trackID, addedAt, trackName, artistName, albumName string
		var isrc, coverURL, coverPath, lyricsPath, videoPath, filePath string
		var durationMs, trackNumber int64
		if err := rows.Scan(&trackID, &addedAt, &trackName, &artistName, &albumName,
			&isrc, &durationMs, &trackNumber, &coverURL, &coverPath, &lyricsPath, &videoPath, &filePath); err == nil {
			results = append(results, map[string]interface{}{
				"trackId":     trackID,
				"trackName":   trackName,
				"artistName":  artistName,
				"albumName":   albumName,
				"isrc":        isrc,
				"durationMs":  durationMs,
				"trackNumber": trackNumber,
				"coverUrl":    coverURL,
				"coverPath":   coverPath,
				"lyricsPath":  lyricsPath,
				"videoPath":   videoPath,
				"filePath":    filePath,
				"addedAt":     addedAt,
			})
		}
	}
	if results == nil {
		results = []map[string]interface{}{}
	}
	out, _ := json.Marshal(results)
	return string(out), nil
}

// RemoveWishlistTrackV2 removes a track from wishlist_tracks.
func RemoveWishlistTrackV2(trackID, isrc, trackName, artistName string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	canonID := CanonicalTrackID(isrc, trackName, artistName)
	db.Exec("DELETE FROM wishlist_tracks WHERE track_id = ?", canonID)
	if trackID != "" && trackID != canonID {
		db.Exec("DELETE FROM wishlist_tracks WHERE track_id = ?", trackID)
	}
	return nil
}
