package database

func GetExistingModTimes() (map[string]int64, error) {
	db, err := Get()
	if err != nil {
		return nil, err
	}
	rows, err := db.Query("SELECT file_path, file_mod_time FROM files WHERE source = 'local_scan'")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	res := make(map[string]int64)
	for rows.Next() {
		var path string
		var mod int64
		if err := rows.Scan(&path, &mod); err == nil {
			res[path] = mod
		}
	}
	return res, nil
}

func SearchLibrary(query string, limit int) ([]LibraryScanResult, error) {
	db, err := Get()
	if err != nil {
		return nil, err
	}
	rows, err := db.Query(`
		SELECT f.id, m.track_name, m.artist_name, m.album_name, m.album_artist, f.file_path, m.cover_path, f.scanned_at, f.file_mod_time, m.isrc, m.track_number, m.total_tracks, m.disc_number, m.total_discs, m.duration_ms, m.release_date, f.bit_depth, f.sample_rate, f.bitrate, m.genre, m.composer, m.label, m.copyright, f.format
		FROM files f
		JOIN metadata m ON f.metadata_id = m.id
		WHERE (m.track_name LIKE ? OR m.artist_name LIKE ? OR m.album_name LIKE ?) AND f.source = 'local_scan'
		LIMIT ?`, "%"+query+"%", "%"+query+"%", "%"+query+"%", limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var results []LibraryScanResult
	for rows.Next() {
		var r LibraryScanResult
		err := rows.Scan(&r.ID, &r.TrackName, &r.ArtistName, &r.AlbumName, &r.AlbumArtist, &r.FilePath, &r.CoverPath, &r.ScannedAt, &r.FileModTime, &r.ISRC, &r.TrackNumber, &r.TotalTracks, &r.DiscNumber, &r.TotalDiscs, &r.Duration, &r.ReleaseDate, &r.BitDepth, &r.SampleRate, &r.Bitrate, &r.Genre, &r.Composer, &r.Label, &r.Copyright, &r.Format)
		if err == nil {
			results = append(results, r)
		}
	}
	return results, nil
}
