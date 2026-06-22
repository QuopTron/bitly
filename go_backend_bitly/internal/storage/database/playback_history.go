package database

import "time"

func LogPlay(trackID, trackName, artistName, albumName, playedAt string, durationMs, percentage int) error {
	db, err := Get()
	if err != nil {
		return err
	}
	if playedAt == "" {
		playedAt = time.Now().UTC().Format(time.RFC3339)
	}
	_, err = db.Exec(`
		INSERT INTO play_history (track_id, track_name, artist_name, album_name, played_at, duration_ms, percentage)
		VALUES (?, ?, ?, ?, ?, ?, ?)`,
		trackID, trackName, artistName, albumName, playedAt, durationMs, percentage)
	return err
}

func GetRecentPlays(limit int) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT * FROM play_history ORDER BY played_at DESC LIMIT ?", limit)
	if err != nil {
		return "", err
	}
	defer rows.Close()
	return rowsToJSON(rows), nil
}

func ClearPlayHistory() error {
	db, err := Get()
	if err != nil {
		return err
	}
	_, err = db.Exec("DELETE FROM play_history")
	return err
}
