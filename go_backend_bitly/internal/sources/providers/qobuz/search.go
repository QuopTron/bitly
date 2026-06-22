package qobuz

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
)

func (c *Client) SearchTracks(query string, limit int) ([]core.ExtTrackMetadata, error) {
	cacheKey := "search:" + strings.ToLower(query) + fmt.Sprintf(":%d", limit)
	if cached := c.getFromCache(cacheKey); cached != nil {
		return cached.([]core.ExtTrackMetadata), nil
	}

	params := map[string]string{"q": query, "offset": "0"}
	if limit > 0 {
		params["limit"] = fmt.Sprintf("%d", limit)
	}

	data, err := c.getJSON("/get-music", params)
	if err != nil {
		return nil, fmt.Errorf("qobuz_kennyy search: %w", err)
	}

	var searchResult struct {
		Query  string    `json:"query"`
		Tracks trackList `json:"tracks"`
	}
	if err := json.Unmarshal(data, &searchResult); err != nil {
		return nil, fmt.Errorf("qobuz_kennyy parse search: %w", err)
	}

	tracks := make([]core.ExtTrackMetadata, 0, len(searchResult.Tracks.Items))
	for _, item := range searchResult.Tracks.Items {
		tracks = append(tracks, core.ExtTrackMetadata{
			ID:          fmt.Sprintf("%d", item.ID),
			Name:        item.Title,
			Artists:     item.Performer.Name,
			AlbumName:   item.Album.Title,
			DurationMS:  item.Duration * 1000,
			TrackNumber: item.TrackNumber,
			ISRC:        item.ISRC,
			QobuzID:     fmt.Sprintf("%d", item.ID),
		})
	}

	c.setCache(cacheKey, tracks, searchCacheTTL)
	return tracks, nil
}

func (c *Client) SearchByISRC(isrc string) (string, error) {
	if isrc == "" {
		return "", fmt.Errorf("empty ISRC")
	}
	cacheKey := "isrc:" + isrc
	if cached := c.getFromCache(cacheKey); cached != nil {
		return cached.(string), nil
	}

	tracks, err := c.SearchTracks(isrc, 5)
	if err != nil {
		return "", fmt.Errorf("qobuz_kennyy search ISRC: %w", err)
	}

	for _, track := range tracks {
		if strings.EqualFold(track.ISRC, isrc) && track.QobuzID != "" {
			c.setCache(cacheKey, track.QobuzID, searchCacheTTL)
			return track.QobuzID, nil
		}
	}
	for _, track := range tracks {
		if track.QobuzID != "" {
			c.setCache(cacheKey, track.QobuzID, searchCacheTTL)
			return track.QobuzID, nil
		}
	}
	return "", fmt.Errorf("qobuz_kennyy: no Qobuz track found for ISRC %s", isrc)
}
