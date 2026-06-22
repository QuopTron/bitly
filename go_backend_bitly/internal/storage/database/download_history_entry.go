package database

import _ "database/sql"

func GetDownloadEntryByID(id string) (string, error) {
	return querySingleEntry("m.id = ? AND f.source = 'download'", id)
}

func GetDownloadEntryBySpotifyID(sid string) (string, error) {
	return querySingleEntry("m.spotify_id = ? AND f.source = 'download'", sid)
}

func GetDownloadEntryByISRC(isrc string) (string, error) {
	return querySingleEntry("m.isrc = ? AND f.source = 'download'", isrc)
}

func FindDownloadEntryByTrackAndArtist(track, artist string) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	row := db.QueryRow(`
		SELECT `+historyColumns()+`
		FROM metadata m JOIN files f ON m.id = f.metadata_id
		WHERE LOWER(m.track_name) = LOWER(?) AND LOWER(m.artist_name) = LOWER(?) AND f.source = 'download'
		LIMIT 1`, track, artist)
	return scanSingleHistoryEntry(row)
}

func querySingleEntry(whereClause string, args ...interface{}) (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	row := db.QueryRow(`
		SELECT `+historyColumns()+`
		FROM metadata m JOIN files f ON m.id = f.metadata_id
		WHERE `+whereClause, args...)
	return scanSingleHistoryEntry(row)
}
