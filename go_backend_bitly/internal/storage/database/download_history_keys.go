package database

import "encoding/json"

func ExistingDownloadTrackKeys(requestsJSON string) (string, error) {
	var requests []TrackKeyRequest
	if err := json.Unmarshal([]byte(requestsJSON), &requests); err != nil {
		return "", err
	}
	db, err := Get()
	if err != nil {
		return "", err
	}

	keys := make(map[string]bool)
	for _, req := range requests {
		var count int
		var qerr error
		switch {
		case req.SpotifyID != "":
			qerr = db.QueryRow("SELECT COUNT(*) FROM metadata WHERE spotify_id = ?", req.SpotifyID).Scan(&count)
		case req.ISRC != "":
			qerr = db.QueryRow("SELECT COUNT(*) FROM metadata WHERE isrc = ?", req.ISRC).Scan(&count)
		case req.TrackName != "":
			qerr = db.QueryRow("SELECT COUNT(*) FROM metadata WHERE LOWER(track_name) = LOWER(?) AND LOWER(artist_name) = LOWER(?)",
				req.TrackName, req.ArtistName).Scan(&count)
		}
		if qerr != nil {
			Log("[DB] ExistingDownloadTrackKeys query warning: %v", qerr)
		}
		keys[req.TrackName+"|"+req.ArtistName] = count > 0
	}
	out, _ := json.Marshal(keys)
	return string(out), nil
}
