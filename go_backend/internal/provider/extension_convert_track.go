package provider

import (
	"fmt"
	"strconv"
)

func toInt(v interface{}) int {
	if v == nil {
		return 0
	}
	switch n := v.(type) {
	case float64:
		return int(n)
	case int64:
		return int(n)
	case int:
		return n
	case string:
		i, _ := strconv.Atoi(n)
		return i
	default:
		return 0
	}
}

func getString(m map[string]interface{}, keys ...string) string {
	for _, k := range keys {
		if v, ok := m[k]; ok && v != nil {
			if s, ok := v.(string); ok && s != "" {
				return s
			}
		}
	}
	return ""
}

func obtenerURLPortada(m map[string]interface{}) string {
	// Delega en el normalizador compartido: además del string directo entiende
	// `images` como objeto o como arreglo de imágenes (Spotify/Apple).
	return PortadaDeCampo(m)
}

// convertirATrackResults normaliza un arreglo JS de tracks a []TrackResult.
func convertirATrackResults(result interface{}, providerName string) ([]TrackResult, error) {
	list, ok := result.([]interface{})
	if !ok {
		return nil, fmt.Errorf("expected array, got %T", result)
	}
	tracks := make([]TrackResult, 0, len(list))
	for _, item := range list {
		m, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
		t := TrackResult{
			ID:        getString(m, "id"),
			Title:     TextoDeCampo(m, "name", "title"),
			Artist:    TextoDeCampo(m, "artists", "artist", "album_artist", "artist_name"),
			ArtistID:  getString(m, "artist_id", "artistId", "artistID"),
			Album:     TextoDeCampo(m, "album_name", "album_title", "albumName", "album"),
			AlbumID:   getString(m, "album_id", "albumId", "albumID"),
			Duration:  DuracionDeCampo(m, "duration_ms", "durationMs", "duration"),
			ISRC:      ISRCDeCampo(m),
			CoverURL:  obtenerURLPortada(m),
			Provider:  providerName,
			SpotifyID: getString(m, "spotify_id", "spotifyId"),
			DeezerID:  getString(m, "deezer_id", "deezerId"),
			TidalID:   getString(m, "tidal_id", "tidalId"),
			QobuzID:   getString(m, "qobuz_id", "qobuzId"),
		}
		if t.ID == "" {
			continue
		}
		t.ID = quitarPrefijo(t.ID)
		tracks = append(tracks, t)
	}
	return tracks, nil
}

// convertirATrackResult normaliza un objeto JS de track a *TrackResult.
func convertirATrackResult(result interface{}, providerName string) (*TrackResult, error) {
	m, ok := result.(map[string]interface{})
	if !ok {
		if wrapper, ok := result.(map[string]interface{}); ok {
			if t, ok := wrapper["track"]; ok {
				if m2, ok := t.(map[string]interface{}); ok {
					m = m2
				}
			}
		}
		if m == nil {
			return nil, fmt.Errorf("expected object, got %T", result)
		}
	}
	t := TrackResult{
		ID:        getString(m, "id"),
		Title:     TextoDeCampo(m, "name", "title"),
		Artist:    TextoDeCampo(m, "artists", "artist", "album_artist", "artist_name"),
		ArtistID:  getString(m, "artist_id", "artistId", "artistID"),
		Album:     TextoDeCampo(m, "album_name", "album_title", "albumName", "album"),
		AlbumID:   getString(m, "album_id", "albumId", "albumID"),
		Duration:  DuracionDeCampo(m, "duration_ms", "durationMs", "duration"),
		ISRC:      ISRCDeCampo(m),
		CoverURL:  obtenerURLPortada(m),
		Provider:  providerName,
		SpotifyID: getString(m, "spotify_id", "spotifyId"),
		DeezerID:  getString(m, "deezer_id", "deezerId"),
		TidalID:   getString(m, "tidal_id", "tidalId"),
		QobuzID:   getString(m, "qobuz_id", "qobuzId"),
	}
	if t.ID != "" {
		t.ID = quitarPrefijo(t.ID)
	}
	return &t, nil
}
