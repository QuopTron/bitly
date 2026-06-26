package api

func extractString(m map[string]interface{}, keys ...string) string {
	for _, key := range keys {
		if v, ok := m[key]; ok && v != nil {
			if s, ok := v.(string); ok && s != "" {
				return s
			}
		}
	}
	return ""
}

func extractInt64(m map[string]interface{}, keys ...string) int64 {
	for _, key := range keys {
		if v, ok := m[key]; ok && v != nil {
			switch n := v.(type) {
			case float64:
				return int64(n)
			case int64:
				return n
			case int:
				return int64(n)
			}
		}
	}
	return 0
}

func ParseSearchResultFromMap(item map[string]interface{}) SearchResult {
	return SearchResult{
		ID:           extractString(item, "id"),
		Name:         extractString(item, "name", "title"),
		Artists:      extractString(item, "artists", "artist", "owner"),
		AlbumName:    extractString(item, "album_name", "albumName", "album"),
		AlbumArtist:  extractString(item, "album_artist", "albumArtist"),
		AlbumID:      extractString(item, "album_id", "albumId"),
		ArtistID:     extractString(item, "artist_id", "artistId"),
		DurationMS:   extractInt64(item, "duration_ms", "durationMs", "duration"),
		CoverURL:     extractString(item, "cover_url", "coverUrl", "image", "thumbnail"),
		Images:       extractString(item, "images"),
		ReleaseDate:  extractString(item, "release_date", "releaseDate", "date"),
		TrackNumber:  int(extractInt64(item, "track_number", "trackNumber")),
		TotalTracks:  int(extractInt64(item, "total_tracks", "totalTracks", "track_count", "trackCount")),
		DiscNumber:   int(extractInt64(item, "disc_number", "discNumber")),
		ISRC:         extractString(item, "isrc"),
		ProviderID:   extractString(item, "provider_id", "providerId"),
		ItemType:     extractString(item, "item_type", "itemType", "type"),
		AlbumType:    extractString(item, "album_type", "albumType"),
		Owner:        extractString(item, "owner"),
		Label:        extractString(item, "label"),
		Genre:        extractString(item, "genre"),
		Composer:     extractString(item, "composer"),
		AudioQuality: extractString(item, "audio_quality", "audioQuality"),
		AudioModes:   extractString(item, "audio_modes", "audioModes"),
		TidalID:      extractString(item, "tidal_id", "tidalId"),
		QobuzID:      extractString(item, "qobuz_id", "qobuzId"),
		DeezerID:     extractString(item, "deezer_id", "deezerId"),
		SpotifyID:    extractString(item, "spotify_id", "spotifyId"),
	}
}

func ParseSearchResultsFromArray(arr []interface{}) []SearchResult {
	results := make([]SearchResult, 0, len(arr))
	for _, item := range arr {
		if m, ok := item.(map[string]interface{}); ok {
			results = append(results, ParseSearchResultFromMap(m))
		}
	}
	return results
}
