package track



func (r *Repository) AddSource(trackID string, source TrackSource) error {
	_, err := r.db.Exec(`
		INSERT INTO track_sources (track_id, provider, provider_track_id, url, quality, format, available)
		VALUES (?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(track_id, provider) DO UPDATE SET
			provider_track_id=excluded.provider_track_id, url=excluded.url,
			quality=excluded.quality, format=excluded.format, available=excluded.available
	`, trackID, source.Provider, source.ProviderID, source.URL,
		source.Quality, source.Format, source.Available)
	return err
}

func (r *Repository) GetSources(trackID string) ([]TrackSource, error) {
	rows, err := r.db.Query(`
		SELECT provider, provider_track_id, COALESCE(url,''), quality, format, available
		FROM track_sources WHERE track_id = ?
	`, trackID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var sources []TrackSource
	for rows.Next() {
		var s TrackSource
		if err := rows.Scan(&s.Provider, &s.ProviderID, &s.URL,
			&s.Quality, &s.Format, &s.Available); err != nil {
			return nil, err
		}
		sources = append(sources, s)
	}
	return sources, nil
}
