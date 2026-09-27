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
			Title:       TextoDeCampo(m, "name", "title"),
			Artist:      TextoDeCampo(m, "artists", "artist", "album_artist", "artist_name"),
			ArtistID:    getString(m, "artist_id", "artistId", "artistID"),
			CoverURL:    obtenerURLPortada(m),
			ReleaseDate: getString(m, "release_date", "releaseDate"),
			TrackCount:  EnteroDeCampo(m, "total_tracks", "totalTracks", "track_count", "nb_tracks"),
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
		Title:       TextoDeCampo(m, "name", "title"),
		Artist:      TextoDeCampo(m, "artists", "artist", "album_artist", "artist_name"),
		ArtistID:    getString(m, "artist_id", "artistId", "artistID"),
		CoverURL:    obtenerURLPortada(m),
		ReleaseDate: getString(m, "release_date", "releaseDate"),
		TrackCount:  EnteroDeCampo(m, "total_tracks", "totalTracks", "track_count", "nb_tracks"),
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
			Name:       TextoDeCampo(m, "name", "title"),
			PictureURL: obtenerURLPortada(m),
			Fans:       EnteroDeCampo(m, "listeners", "fans"),
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
		Name:       TextoDeCampo(m, "name", "title"),
		PictureURL: obtenerURLPortada(m),
		Fans:       EnteroDeCampo(m, "listeners", "fans"),
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
			Title:       TextoDeCampo(m, "name", "title"),
			Description: TextoDeCampo(m, "description"),
			Creator:     TextoDeCampo(m, "owner", "creator", "artist", "artists"),
			TrackCount:  EnteroDeCampo(m, "track_count", "total_tracks", "totalTracks", "itemCount"),
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
