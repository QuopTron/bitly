package share

import "strings"

func collectionItemName(t *extTrack, isArtist bool) string {
	if t == nil {
		return ""
	}
	if isArtist {
		if isItemType(t, "artist") {
			return t.Name
		}
		return t.Artists
	}
	if isItemType(t, "album") {
		return t.Name
	}
	return t.AlbumName
}

func isItemType(t *extTrack, itemType string) bool {
	return strings.EqualFold(strings.TrimSpace(t.ItemType), itemType)
}

func collectionID(t *extTrack, itemType string) string {
	if isItemType(t, itemType) {
		return t.ID
	}
	return ""
}

func firstNonEmptyString(values ...string) string {
	for _, v := range values {
		if strings.TrimSpace(v) != "" {
			return v
		}
	}
	return ""
}
