package gobackend

import (
	"encoding/json"
)

// appendSearchStream deduplicates and appends items to the stream buffer.
func anexarSearchStream(gen int64, items []FeedItemGo) {
	currentSearchStream.mu.Lock()
	defer currentSearchStream.mu.Unlock()
	if currentSearchStream.generation != gen {
		return // search was superseded by a new query
	}
	for _, item := range items {
		if esItemBusquedaDuplicado(currentSearchStream.items, item) {
			continue
		}
		currentSearchStream.items = append(currentSearchStream.items, item)
	}
}

// isDuplicateSearchItem checks if an item already exists in the list.
// For tracks: dedup by ISRC, then by title+artist.
// For collections: dedup by type+id.
func esItemBusquedaDuplicado(existing []FeedItemGo, item FeedItemGo) bool {
	if item.Type == "track" {
		if item.ISRC != "" {
			for _, e := range existing {
				if e.Type == "track" && e.ISRC == item.ISRC {
					return true
				}
			}
		}
		// Fallback: title+artist dedup
		for _, e := range existing {
			if e.Type == "track" && e.Name == item.Name && e.Artists == item.Artists {
				return true
			}
		}
		return false
	}
	// Albums/artists/playlists: dedup by type+id
	for _, e := range existing {
		if e.Type == item.Type && e.ID == item.ID {
			return true
		}
	}
	return false
}

// GetSearchStreamResults returns the accumulated results for the current
// streaming search. Flutter polls this every ~500ms.
// Response: { items: [...], done: bool, generation: int64 }
func GetSearchStreamResults() string {
	currentSearchStream.mu.Lock()
	gen := currentSearchStream.generation
	items := make([]FeedItemGo, len(currentSearchStream.items))
	copy(items, currentSearchStream.items)
	done := currentSearchStream.done
	currentSearchStream.mu.Unlock()

	data, _ := json.Marshal(map[string]interface{}{
		"items":      items,
		"done":       done,
		"generation": gen,
	})
	return string(data)
}
