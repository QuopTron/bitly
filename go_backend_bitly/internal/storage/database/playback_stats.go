package database

import "encoding/json"

func GetTotalStats() (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	var totalPlays, tracks, albums, artists int
	if err := db.QueryRow("SELECT COALESCE(SUM(play_count),0) FROM play_aggregates WHERE type = 'track'").Scan(&totalPlays); err != nil {
		Log("[DB] GetTotalStats totalPlays warning: %v", err)
	}
	if err := db.QueryRow("SELECT COUNT(*) FROM play_aggregates WHERE type = 'track'").Scan(&tracks); err != nil {
		Log("[DB] GetTotalStats tracks warning: %v", err)
	}
	if err := db.QueryRow("SELECT COUNT(*) FROM play_aggregates WHERE type = 'album'").Scan(&albums); err != nil {
		Log("[DB] GetTotalStats albums warning: %v", err)
	}
	if err := db.QueryRow("SELECT COUNT(*) FROM play_aggregates WHERE type = 'artist'").Scan(&artists); err != nil {
		Log("[DB] GetTotalStats artists warning: %v", err)
	}

	result := map[string]interface{}{
		"totalPlays":    totalPlays,
		"uniqueTracks":  tracks,
		"uniqueAlbums":  albums,
		"uniqueArtists": artists,
		"totalDays":     0,
	}
	out, err := json.Marshal(result)
	if err != nil {
		return "", err
	}
	return string(out), nil
}

func GetTopTracks(limit int) (string, error) {
	return queryAggregates("track", limit)
}

func GetTopAlbums(limit int) (string, error) {
	return queryAggregates("album", limit)
}

func GetTopArtists(limit int) (string, error) {
	return queryAggregates("artist", limit)
}

func queryAggregates(itemType string, limit int) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT * FROM play_aggregates WHERE type = ? ORDER BY play_count DESC LIMIT ?", itemType, limit)
	if err != nil {
		return "", err
	}
	defer rows.Close()
	return rowsToJSON(rows), nil
}
