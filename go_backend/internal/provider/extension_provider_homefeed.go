package provider

import (
	"encoding/json"
	"fmt"
)

type HomeFeedSection struct {
	URI   string         `json:"uri"`
	Title string         `json:"title"`
	Items []HomeFeedItem `json:"items"`
}

// HomeFeedItem represents a single item in a home feed section.
// Compatible with SpotiFLAC-Mobile extension format.
type HomeFeedItem struct {
	Name       string `json:"name"`
	Artists    string `json:"artists"`
	DurationMs int    `json:"duration_ms,omitempty"`
	ItemType   string `json:"type"`
	ItemID     string `json:"id"`
	AlbumID    string `json:"album_id,omitempty"`
	AlbumName  string `json:"album_name,omitempty"`
	ThumbURL   string `json:"cover_url,omitempty"`
}

// GetHomeFeed calls the extension's getHomeFeed() JS function.
func (p *ExtensionProvider) GetHomeFeed() ([]HomeFeedSection, error) {
	// Home-feed requests get their own cooldown bucket so a rate-limited feed
	// endpoint doesn't disable playback/search for this provider.
	result, err := p.callOp("feed", "getHomeFeed")
	if err != nil {
		return nil, fmt.Errorf("ext %s getHomeFeed: %w", p.extID, err)
	}
	if result == nil {
		return nil, nil
	}

	// Convert the JS result to JSON bytes so we can unmarshal properly
	// (Goja returns int64/float64, not int; json.Unmarshal handles all types)
	raw, err := json.Marshal(result)
	if err != nil {
		return nil, fmt.Errorf("ext %s: marshal getHomeFeed result: %w", p.extID, err)
	}

	var feedResult struct {
		Success  bool              `json:"success"`
		Sections []HomeFeedSection `json:"sections"`
	}
	if err := json.Unmarshal(raw, &feedResult); err != nil {
		return nil, fmt.Errorf("ext %s: unmarshal getHomeFeed: %w", p.extID, err)
	}

	if !feedResult.Success || len(feedResult.Sections) == 0 {
		return nil, nil
	}

	// For YouTube Music, fill in missing thumbnails using video ID pattern
	if p.extID == "ytmusic-spotiflac" {
		for si := range feedResult.Sections {
			for ii := range feedResult.Sections[si].Items {
				item := &feedResult.Sections[si].Items[ii]
				if item.ThumbURL == "" && item.ItemID != "" {
					item.ThumbURL = "https://img.youtube.com/vi/" + item.ItemID + "/mqdefault.jpg"
				}
			}
		}
	}

	return feedResult.Sections, nil
}

// EnrichTrackResult holds the extra fields resolved by an extension's
// enrichTrack() call (ISRC and cross-provider IDs from Odesli/SongLink).
