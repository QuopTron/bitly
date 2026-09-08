package gobackend

func extraerTracksDetalle(m map[string]interface{}, source string) []detailTrack {
	lists := []string{"tracks", "track_list", "songs", "items", "data", "top_tracks", "topTracks", "top-songs"}
	for _, key := range lists {
		raw, ok := m[key]
		if !ok {
			continue
		}
		items, ok := raw.([]interface{})
		if !ok || len(items) == 0 {
			continue
		}
		result := make([]detailTrack, 0, len(items))
		for _, it := range items {
			tm, ok := it.(map[string]interface{})
			if !ok {
				continue
			}
			tid := stringDetalle(tm, "id", "track_id", "trackId")
			tname := stringDetalle(tm, "name", "title")
			if tid == "" && tname == "" {
				continue
			}
			// Prefer the track's own provider_id when present (extensions tag
			// every track with it) — a playlist can mix tracks from different
			// providers, and forcing the collection source misroutes playback.
			provider := stringDetalle(tm, "provider_id", "providerId")
			if provider == "" {
				provider = source
			}
			result = append(result, detailTrack{
				TrackID:     tid,
				Name:        tname,
				DurationMs:  intDetalle(tm, "duration_ms", "durationMs"),
				TrackNumber: intDetalle(tm, "track_number", "trackNumber"),
				ISRC:        stringDetalle(tm, "isrc"),
				CoverURL:    portadaDetalle(tm),
				ArtistName:  stringDetalle(tm, "artists", "artist", "artist_name"),
				AlbumName:   stringDetalle(tm, "album_name", "album", "albumName"),
				Provider:    provider,
				SpotifyID:   stringDetalle(tm, "spotify_id", "spotifyId"),
				DeezerID:    stringDetalle(tm, "deezer_id", "deezerId"),
				TidalID:     stringDetalle(tm, "tidal_id", "tidalId"),
				QobuzID:     stringDetalle(tm, "qobuz_id", "qobuzId"),
			})
		}
		return result
	}
	return []detailTrack{}
}

// extractDetailAlbums pulls the album list from an artist detail object.
func extraerAlbumesDetalle(m map[string]interface{}) []detailAlbum {
	lists := []string{"albums", "top_albums", "topAlbums", "releases"}
	for _, key := range lists {
		raw, ok := m[key]
		if !ok {
			continue
		}
		items, ok := raw.([]interface{})
		if !ok || len(items) == 0 {
			continue
		}
		result := make([]detailAlbum, 0, len(items))
		for _, it := range items {
			am, ok := it.(map[string]interface{})
			if !ok {
				continue
			}
			aid := stringDetalle(am, "id", "album_id", "albumId")
			aname := stringDetalle(am, "name", "title")
			if aid == "" && aname == "" {
				continue
			}
			result = append(result, detailAlbum{
				AlbumID:     aid,
				Name:        aname,
				CoverURL:    portadaDetalle(am),
				ReleaseDate: stringDetalle(am, "release_date", "releaseDate"),
				TotalTracks: intDetalle(am, "total_tracks", "totalTracks", "track_count"),
			})
		}
		return result
	}
	return []detailAlbum{}
}
