package provider

import (
	"fmt"
	"strings"
)

func convertToAlbumResults(result interface{}, providerName string) ([]AlbumResult, error) {
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
			CoverURL:    getCoverURL(m),
			ReleaseDate: getString(m, "release_date", "releaseDate"),
			TrackCount:  toInt(m["total_tracks"]),
			Provider:    providerName,
		}
		if a.ID != "" {
			a.ID = stripPrefix(a.ID)
		}
		if a.ID != "" {
			albums = append(albums, a)
		}
	}
	return albums, nil
}

func convertToAlbumResult(result interface{}, providerName string) (*AlbumResult, error) {
	m, ok := result.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("expected object, got %T", result)
	}
	a := AlbumResult{
		ID:          getString(m, "id"),
		Title:       getString(m, "name", "title"),
		Artist:      getString(m, "artists", "artist"),
		ArtistID:    getString(m, "artist_id", "artistId", "artistID"),
		CoverURL:    getCoverURL(m),
		ReleaseDate: getString(m, "release_date", "releaseDate"),
		TrackCount:  toInt(m["total_tracks"]),
		Provider:    providerName,
	}
	if a.ID != "" {
		a.ID = stripPrefix(a.ID)
	}
	return &a, nil
}

func convertToArtistResults(result interface{}, providerName string) ([]ArtistResult, error) {
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
			PictureURL: getCoverURL(m),
			Fans:       toInt(m["listeners"]),
			Provider:   providerName,
		}
		if a.ID != "" {
			a.ID = stripPrefix(a.ID)
		}
		if a.ID != "" {
			artists = append(artists, a)
		}
	}
	return artists, nil
}

func convertToArtistResult(result interface{}, providerName string) (*ArtistResult, error) {
	m, ok := result.(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("expected object, got %T", result)
	}
	a := ArtistResult{
		ID:         getString(m, "id"),
		Name:       getString(m, "name"),
		PictureURL: getCoverURL(m),
		Fans:       toInt(m["listeners"]),
		Provider:   providerName,
	}
	if a.ID != "" {
		a.ID = stripPrefix(a.ID)
	}
	return &a, nil
}

func convertToPlaylistResults(result interface{}, providerName string) ([]PlaylistResult, error) {
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
			CoverURL:    getCoverURL(m),
			Provider:    providerName,
		}
		if p.ID != "" {
			p.ID = stripPrefix(p.ID)
		}
		if p.ID != "" {
			playlists = append(playlists, p)
		}
	}
	return playlists, nil
}

// stripPrefix removes provider: prefix from IDs (e.g., "deezer:123" -> "123").
func stripPrefix(id string) string {
	if idx := strings.IndexByte(id, ':'); idx >= 0 {
		return id[idx+1:]
	}
	return id
}
