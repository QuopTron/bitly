package provider

import (
	"fmt"
	"strings"
)

// convertirAAlbumResults normaliza un arreglo JS de albumes a []AlbumResult.
func convertirAAlbumResults(result interface{}, providerName string) ([]AlbumResult, error) {
	list, ok := result.([]interface{})
	if !ok {
		return nil, fmt.Errorf("expected array, got %T", result)
	}
	albums := make([]AlbumResult, 0, len(list))
	for _, item := range list {
		m, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
		a := AlbumResult{
			ID:          getString(m, "id"),
			Title:       getString(m, "name", "title"),
			Artist:      getString(m, "artists", "artist"),
			ArtistID:    getString(m, "artist_id", "artistId", "artistID"),
			CoverURL:    obtenerURLPortada(m),
			ReleaseDate: getString(m, "release_date", "releaseDate"),
			TrackCount:  toInt(m["total_tracks"]),
			Provider:    providerName,
		}
		if a.ID != "" {
			a.ID = quitarPrefijo(a.ID)
		}
		if a.ID != "" {
			albums = append(albums, a)
		}
	}
	return albums, nil
}

// convertirAAlbumResult normaliza un objeto JS de album a *AlbumResult.
func convertirAAlbumResult(result interface{}, providerName string) (*AlbumResult, error) {
	m, ok := result.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("expected object, got %T", result)
	}
	a := AlbumResult{
		ID:          getString(m, "id"),
		Title:       getString(m, "name", "title"),
		Artist:      getString(m, "artists", "artist"),
		ArtistID:    getString(m, "artist_id", "artistId", "artistID"),
		CoverURL:    obtenerURLPortada(m),
		ReleaseDate: getString(m, "release_date", "releaseDate"),
		TrackCount:  toInt(m["total_tracks"]),
		Provider:    providerName,
	}
	if a.ID != "" {
		a.ID = quitarPrefijo(a.ID)
	}
	return &a, nil
}

// convertirAArtistResults normaliza un arreglo JS de artistas a []ArtistResult.
func convertirAArtistResults(result interface{}, providerName string) ([]ArtistResult, error) {
	list, ok := result.([]interface{})
	if !ok {
		return nil, fmt.Errorf("expected array, got %T", result)
	}
	artists := make([]ArtistResult, 0, len(list))
	for _, item := range list {
		m, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
		a := ArtistResult{
			ID:         getString(m, "id"),
			Name:       getString(m, "name"),
			PictureURL: obtenerURLPortada(m),
			Fans:       toInt(m["listeners"]),
			Provider:   providerName,
		}
		if a.ID != "" {
			a.ID = quitarPrefijo(a.ID)
		}
		if a.ID != "" {
			artists = append(artists, a)
		}
	}
	return artists, nil
}

// convertirAArtistResult normaliza un objeto JS de artista a *ArtistResult.
func convertirAArtistResult(result interface{}, providerName string) (*ArtistResult, error) {
	m, ok := result.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("expected object, got %T", result)
	}
	a := ArtistResult{
		ID:         getString(m, "id"),
		Name:       getString(m, "name"),
		PictureURL: obtenerURLPortada(m),
		Fans:       toInt(m["listeners"]),
		Provider:   providerName,
	}
	if a.ID != "" {
		a.ID = quitarPrefijo(a.ID)
	}
	return &a, nil
}

// convertirAPlaylistResults normaliza un arreglo JS de listas a []PlaylistResult.
func convertirAPlaylistResults(result interface{}, providerName string) ([]PlaylistResult, error) {
	list, ok := result.([]interface{})
	if !ok {
		return nil, fmt.Errorf("expected array, got %T", result)
	}
	playlists := make([]PlaylistResult, 0, len(list))
	for _, item := range list {
		m, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
		p := PlaylistResult{
			ID:          getString(m, "id"),
			Title:       getString(m, "name", "title"),
			Description: getString(m, "description"),
			Creator:     getString(m, "owner", "creator", "artist", "artists"),
			TrackCount:  toInt(m["track_count"]),
			CoverURL:    obtenerURLPortada(m),
			Provider:    providerName,
		}
		if p.ID != "" {
			p.ID = quitarPrefijo(p.ID)
		}
		if p.ID != "" {
			playlists = append(playlists, p)
		}
	}
	return playlists, nil
}

// quitarPrefijo elimina el prefijo de proveedor de los IDs (p. ej. "deezer:123" -> "123").
func quitarPrefijo(id string) string {
	if idx := strings.IndexByte(id, ':'); idx >= 0 {
		return id[idx+1:]
	}
	return id
}
