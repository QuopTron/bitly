package share

import "strings"

func (s *Service) resolveShareURL(extID string, track *extTrack, itemType string) string {
	if track == nil {
		return ""
	}

	if itemType == "album" {
		if isItemType(track, "album") {
			if url := normalizeShareURL(track.ExternalURL); url != "" {
				return url
			}
		}
		if url := normalizeShareURL(track.AlbumURL); url != "" {
			return url
		}
		if url := urlFromExternalLinks(track.ExternalLinks, "album"); url != "" {
			return url
		}
		id := firstNonEmptyString(track.AlbumID, collectionID(track, "album"), track.AlbumURL)
		if id != "" {
			if url := s.templateShareURL(extID, "album", id); url != "" {
				return url
			}
		}
		return ""
	}

	if isItemType(track, "artist") {
		if url := normalizeShareURL(track.ExternalURL); url != "" {
			return url
		}
	}
	if url := normalizeShareURL(track.ArtistURL); url != "" {
		return url
	}
	if url := urlFromExternalLinks(track.ExternalLinks, "artist"); url != "" {
		return url
	}
	id := firstNonEmptyString(track.ArtistID, collectionID(track, "artist"))
	if id != "" {
		if url := s.templateShareURL(extID, "artist", id); url != "" {
			return url
		}
	}
	return ""
}

func (s *Service) templateShareURL(extID, itemType, id string) string {
	if id == "" {
		return ""
	}
	id = stripProviderPrefix(strings.TrimSpace(id))
	if id == "" {
		return ""
	}

	ext, err := s.manager.GetExtension(extID)
	if err != nil || ext == nil || ext.Capabilities == nil {
		return ""
	}

	templatesRaw, ok := ext.Capabilities["shareUrlTemplates"]
	if !ok {
		return ""
	}

	templates, ok := templatesRaw.(map[string]interface{})
	if !ok {
		return ""
	}

	rawTemplate, ok := templates[itemType].(string)
	if !ok {
		return ""
	}
	rawTemplate = strings.TrimSpace(rawTemplate)
	if rawTemplate == "" {
		return ""
	}

	return strings.ReplaceAll(rawTemplate, "{id}", id)
}

func normalizeShareURL(value string) string {
	trimmed := strings.TrimSpace(value)
	if strings.HasPrefix(trimmed, "http://") || strings.HasPrefix(trimmed, "https://") {
		return trimmed
	}
	return ""
}

func urlFromExternalLinks(links map[string]string, preferredKey string) string {
	for key, value := range links {
		if strings.Contains(strings.ToLower(key), preferredKey) {
			if url := normalizeShareURL(value); url != "" {
				return url
			}
		}
	}
	return ""
}

func stripProviderPrefix(id string) string {
	if idx := strings.Index(id, ":"); idx > 0 && idx < len(id)-1 {
		return id[idx+1:]
	}
	return id
}
