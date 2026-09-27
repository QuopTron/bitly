package provider

import (
	"encoding/json"
	"fmt"
	"strings"
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
	// Identidad opcional del item. Un catálogo que la conoce (deezer, qobuz,
	// tidal...) la manda y el toque desde el feed resuelve por identidad exacta
	// (CheckAvailability / ISRC) en vez de una búsqueda lenta por nombre, que es
	// justo donde el matching entre fuentes puede fallar. Las extensiones que no
	// la tienen la omiten y todo sigue igual.
	ISRC      string `json:"isrc,omitempty"`
	SpotifyID string `json:"spotify_id,omitempty"`
	DeezerID  string `json:"deezer_id,omitempty"`
	TidalID   string `json:"tidal_id,omitempty"`
	QobuzID   string `json:"qobuz_id,omitempty"`
}

// UnmarshalJSON lee el item del feed con el MISMO normalizador que el resto de
// las vistas: cada extensión escribe el feed a su manera y un `artists` en
// arreglo o un `album` en objeto hacían fallar el unmarshal entero (campo string
// con arreglo) y la fuente quedaba sin feed. Con esto, las nueve se leen igual.
func (h *HomeFeedItem) UnmarshalJSON(b []byte) error {
	var m map[string]interface{}
	if err := json.Unmarshal(b, &m); err != nil {
		return err
	}
	h.Name = TextoDeCampo(m, "name", "title")
	h.Artists = TextoDeCampo(m, "artists", "artist", "album_artist", "artist_name")
	h.DurationMs = DuracionDeCampo(m, "duration_ms", "durationMs", "duration")
	h.ItemType = getString(m, "type", "item_type")
	h.ItemID = getString(m, "id", "item_id")
	h.AlbumID = getString(m, "album_id", "albumId", "albumID")
	h.AlbumName = TextoDeCampo(m, "album_name", "album_title", "albumName", "album")
	h.ThumbURL = PortadaDeCampo(m)
	h.ISRC = ISRCDeCampo(m)
	h.SpotifyID = getString(m, "spotify_id", "spotifyId")
	h.DeezerID = getString(m, "deezer_id", "deezerId")
	h.TidalID = getString(m, "tidal_id", "tidalId")
	h.QobuzID = getString(m, "qobuz_id", "qobuzId")
	if strings.TrimSpace(h.ItemType) == "" {
		h.ItemType = "track"
	}
	return nil
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
