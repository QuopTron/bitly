package database

import (
	"encoding/json"
)

// GetPlayStatsV2 returns play stats for an item type and optional ID.
func GetPlayStatsV2(itemType, itemID string) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	if itemID != "" {
		var playCount int64
		var lastPlayed string
		err := db.QueryRow(`SELECT COALESCE(play_count,0), COALESCE(last_played_at,'')
			FROM play_aggregates WHERE item_id = ? AND type = ?`, itemID, itemType).Scan(&playCount, &lastPlayed)
		if err != nil {
			playCount = 0
			lastPlayed = ""
		}
		result := map[string]interface{}{
			"itemId":     itemID,
			"type":       itemType,
			"playCount":  playCount,
			"lastPlayed": lastPlayed,
		}
		out, _ := json.Marshal(result)
		return string(out), nil
	}

	var query string
	switch itemType {
	case "track":
		query = `SELECT pa.item_id, pa.play_count, pa.last_played_at,
			COALESCE(t.name,'') as track_name, COALESCE(a.name,'') as artist_name
			FROM play_aggregates pa
			LEFT JOIN tracks t ON t.id = pa.item_id
			LEFT JOIN artists a ON a.id = t.artist_id
			WHERE pa.type = 'track' ORDER BY pa.play_count DESC`
	case "album":
		query = `SELECT pa.item_id, pa.play_count, pa.last_played_at,
			COALESCE(al.name,'') as album_name, COALESCE(a.name,'') as artist_name
			FROM play_aggregates pa
			LEFT JOIN albums al ON al.id = pa.item_id
			LEFT JOIN artists a ON a.id = al.artist_id
			WHERE pa.type = 'album' ORDER BY pa.play_count DESC`
	case "artist":
		query = `SELECT pa.item_id, pa.play_count, pa.last_played_at,
			COALESCE(a.name,'') as artist_name
			FROM play_aggregates pa
			LEFT JOIN artists a ON a.id = pa.item_id
			WHERE pa.type = 'artist' ORDER BY pa.play_count DESC`
	default:
		results := []map[string]interface{}{}
		out, _ := json.Marshal(results)
		return string(out), nil
	}

	rows, err := db.Query(query)
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var results []map[string]interface{}
	for rows.Next() {
		var itemID string
		var playCount int64
		var lastPlayed string
		var name1, name2 string
		if itemType == "track" || itemType == "album" {
			if err := rows.Scan(&itemID, &playCount, &lastPlayed, &name1, &name2); err == nil {
				entry := map[string]interface{}{
					"itemId": itemID, "playCount": playCount, "lastPlayed": lastPlayed,
				}
				if itemType == "track" {
					entry["trackName"] = name1
					entry["artistName"] = name2
				} else {
					entry["albumName"] = name1
					entry["artistName"] = name2
				}
				results = append(results, entry)
			}
		} else {
			if err := rows.Scan(&itemID, &playCount, &lastPlayed, &name1); err == nil {
				results = append(results, map[string]interface{}{
					"itemId": itemID, "playCount": playCount, "lastPlayed": lastPlayed,
					"artistName": name1,
				})
			}
		}
	}
	if results == nil {
		results = []map[string]interface{}{}
	}
	out, _ := json.Marshal(results)
	return string(out), nil
}
