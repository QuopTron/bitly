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

func getCoverURL(m map[string]interface{}) string {
	return getString(m, "cover_url", "coverUrl", "cover",
		"images", "image_url", "picture_xl", "picture_big",
		"picture_medium", "picture")
}

func convertToTrackResults(result interface{}, providerName string) ([]TrackResult, error) {
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
			ID:       getString(m, "id"),
			Title:    getString(m, "name", "title"),
			Artist:   getString(m, "artists", "artist"),
			ArtistID: getString(m, "artist_id", "artistId", "artistID"),
			Album:    getString(m, "album_name", "album"),
			AlbumID:  getString(m, "album_id", "albumId", "albumID"),
			Duration: toInt(m["duration_ms"]),
			ISRC:     getString(m, "isrc"),
			CoverURL: getCoverURL(m),
			Provider: providerName,
		}
		if t.ID == "" {
			continue
		}
		t.ID = stripPrefix(t.ID)
		tracks = append(tracks, t)
	}
	return tracks, nil
}

func convertToTrackResult(result interface{}, providerName string) (*TrackResult, error) {
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
		ID:       getString(m, "id"),
		Title:    getString(m, "name", "title"),
		Artist:   getString(m, "artists", "artist"),
		ArtistID: getString(m, "artist_id", "artistId", "artistID"),
		Album:    getString(m, "album_name", "album"),
		AlbumID:  getString(m, "album_id", "albumId", "albumID"),
		Duration: toInt(m["duration_ms"]),
		ISRC:     getString(m, "isrc"),
		CoverURL: getCoverURL(m),
		Provider: providerName,
	}
	if t.ID != "" {
		t.ID = stripPrefix(t.ID)
	}
	return &t, nil
}
