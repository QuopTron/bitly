package database

func ClearAllStats() error {
	db, err := Get()
	if err != nil {
		return err
	}
	tables := []string{"play_history", "play_aggregates", "secret_counters", "secret_unlocks"}
	for _, t := range tables {
		if _, err := db.Exec("DELETE FROM " + t); err != nil {
			return err
		}
	}
	return nil
}

func ResetDatabase() error {
	db, err := Get()
	if err != nil {
		return err
	}
	tables := []string{
		"metadata", "files", "favorites", "collections", "collection_items",
		"play_history", "play_aggregates", "secret_counters", "secret_unlocks",
		"download_queue", "recent_access", "hidden_download_ids", "application_state",
		"favorite_artists", "favorite_albums", "loved_tracks",
		"sources", "tracks", "albums", "artists",
		"isrc_cache", "video_url_cache",
	}
	for _, table := range tables {
		_, _ = db.Exec("DELETE FROM " + table)
	}
	return nil
}
