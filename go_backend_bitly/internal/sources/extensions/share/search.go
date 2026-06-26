package share

import "encoding/json"

func (s *Service) findForExtension(extID, itemType, name, artists, query string) CrossExtensionShareResult {
	result := CrossExtensionShareResult{
		ExtensionID: extID,
	}
	if ext, err := s.manager.GetExtension(extID); err == nil && ext != nil {
		result.DisplayName = ext.Name
		if result.DisplayName == "" {
			result.DisplayName = ext.ID
		}
	} else {
		result.DisplayName = extID
	}

	tracks, err := s.searchCandidates(extID, itemType, query)
	if err != nil {
		result.Error = err.Error()
		return result
	}
	if len(tracks) == 0 {
		result.Error = "no results"
		return result
	}

	var best *extTrack
	switch itemType {
	case "artist":
		best = bestArtistTrack(tracks, name)
	case "album":
		best = bestAlbumTrack(tracks, name, artists)
	default:
		result.Error = "unsupported collection type"
		return result
	}
	if best == nil {
		result.Error = itemType + " not found"
		return result
	}

	url := s.resolveShareURL(extID, best, itemType)
	if url == "" {
		result.Error = itemType + " found without shareable link"
		return result
	}

	result.Found = true
	result.URL = url
	if itemType == "artist" {
		result.ItemName = collectionItemName(best, true)
	} else {
		result.ItemName = collectionItemName(best, false)
		result.ItemArtists = best.Artists
	}
	return result
}

// extensionFilter returns the filter value an extension expects for a given search type.
// Different extensions use different conventions (singular vs plural, or custom like "songs").
// This mirrors the same logic in handlers/search.go.
func extensionFilter(extID, searchType string) string {
	overrides := map[string]map[string]string{
		"amazon": {
			"track":    "songs",
			"album":    "albums",
			"artist":   "artists",
			"playlist": "playlists",
		},
		"deezer": {
			"track":    "track",
			"album":    "album",
			"artist":   "artist",
			"playlist": "playlist",
		},
		"qobuz-web": {
			"track":  "track",
			"album":  "album",
			"artist": "artist",
		},
		"tidal-web": {
			"track":    "track",
			"album":    "album",
			"artist":   "artist",
			"playlist": "playlist",
		},
	}
	if extMap, ok := overrides[extID]; ok {
		if f, ok := extMap[searchType]; ok {
			return f
		}
	}
	// Default: plural convention (apple-music, soundcloud, spotify-web, ytmusic-spotiflac, etc.)
	switch searchType {
	case "track":
		return "tracks"
	case "album":
		return "albums"
	case "artist":
		return "artists"
	case "playlist":
		return "playlists"
	}
	return ""
}

func (s *Service) searchCandidates(extID, itemType, query string) ([]extTrack, error) {
	filter := extensionFilter(extID, itemType)

	if filter != "" {
		options := map[string]interface{}{
			"filter": filter,
			"limit":  10,
		}
		if result, err := s.runtime.CallMethod(extID, "customSearch", query, options); err == nil && result != nil && result.Value != nil {
			if tracks := parseExtTracks(result.RawJSON); len(tracks) > 0 {
				return tracks, nil
			}
		}
	}

	result, err := s.client.SearchTracks(extID, query, 10)
	if err != nil || len(result) == 0 {
		return nil, err
	}

	tracks := make([]extTrack, len(result))
	for i, r := range result {
		tracks[i] = extTrack{
			ID:         r.ID,
			Name:       r.Name,
			Artists:    r.Artists,
			AlbumName:  r.AlbumName,
			DurationMS: int(r.DurationMS),
			CoverURL:   r.CoverURL,
			ISRC:       r.ISRC,
		}
	}
	return tracks, nil
}

func parseExtTracks(rawJSON string) []extTrack {
	var tracks []extTrack
	if err := json.Unmarshal([]byte(rawJSON), &tracks); err == nil && len(tracks) > 0 {
		return tracks
	}

	var wrapper struct {
		Tracks []extTrack `json:"tracks"`
		Total  int        `json:"total"`
	}
	if err := json.Unmarshal([]byte(rawJSON), &wrapper); err == nil && len(wrapper.Tracks) > 0 {
		return wrapper.Tracks
	}

	return nil
}
