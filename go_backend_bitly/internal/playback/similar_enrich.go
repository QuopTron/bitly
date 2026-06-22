package playback

import "github.com/zarz/bitly/go_backend_bitly/internal/storage/database"

func enrichWithLocalAvailability(tracks []map[string]interface{}) {
	if len(tracks) == 0 {
		return
	}

	db, err := database.Get()
	if err != nil {
		return
	}

	for i, track := range tracks {
		isrc, _ := track["isrc"].(string)

		var filePath string
		if isrc != "" {
			err := db.QueryRow(`
				SELECT f.file_path FROM files f
				JOIN metadata m ON f.metadata_id = m.id
				WHERE m.isrc = ? AND f.source IN ('download', 'local_scan')
				LIMIT 1`, isrc).Scan(&filePath)
			if err == nil && filePath != "" {
				tracks[i]["local_path"] = filePath
				tracks[i]["is_available_offline"] = true
				continue
			}
		}

		name, _ := track["name"].(string)
		artistName, _ := track["artistName"].(string)

		if name != "" && artistName != "" {
			err := db.QueryRow(`
				SELECT f.file_path FROM files f
				JOIN metadata m ON f.metadata_id = m.id
				WHERE LOWER(m.track_name) = LOWER(?) AND LOWER(m.artist_name) = LOWER(?)
				AND f.source IN ('download', 'local_scan')
				LIMIT 1`, name, artistName).Scan(&filePath)
			if err == nil && filePath != "" {
				tracks[i]["local_path"] = filePath
				tracks[i]["is_available_offline"] = true
			}
		}
	}
}
