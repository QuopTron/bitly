package database

func nvl(v interface{}) interface{} {
	if v == nil {
		return ""
	}
	switch val := v.(type) {
	case string:
		return val
	default:
		return v
	}
}

func historyColumns() string {
	return `m.id, m.track_name, m.artist_name, m.album_name, m.album_artist,
		m.cover_url, m.cover_path, m.isrc, m.duration_ms, m.track_number,
		m.total_tracks, m.disc_number, m.total_discs, m.release_date,
		m.genre, m.composer, m.label, m.copyright, m.spotify_id,
		f.file_path, f.format, f.bitrate, f.bit_depth, f.sample_rate,
		f.downloaded_at, f.saf_file_name, f.source,
		f.bit_depth as eff_bit_depth,
		f.sample_rate as eff_sample_rate`
}

func libraryColumns() string {
	return `m.id, m.track_name, m.artist_name, m.album_name, m.album_artist,
		m.isrc, m.track_number, m.total_tracks, m.disc_number, m.total_discs,
		m.duration_ms, m.release_date, m.genre, m.composer, m.label, m.copyright,
		m.cover_path, f.file_path, f.format, f.bitrate, f.bit_depth, f.sample_rate,
		f.file_mod_time, f.scanned_at`
}
