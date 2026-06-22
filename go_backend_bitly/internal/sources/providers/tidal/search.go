package tidal

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
)

func (c *Client) SearchByISRC(isrc string) (*core.ExtTrackMetadata, error) {
	cacheKey := "isrc:" + isrc
	if cached := c.getFromCache(cacheKey); cached != nil {
		return cached.(*core.ExtTrackMetadata), nil
	}

	baseURLs := c.getBaseURLs()
	for _, baseURL := range baseURLs {
		u := fmt.Sprintf("%s/search/?i=%s", baseURL, url.QueryEscape(isrc))
		resp, err := c.httpClient.Get(u)
		if err != nil {
			continue
		}
		body, readErr := io.ReadAll(resp.Body)
		resp.Body.Close()
		if readErr != nil || resp.StatusCode != http.StatusOK {
			continue
		}
		var searchResp searchResponse
		if err := json.Unmarshal(body, &searchResp); err != nil {
			continue
		}
		if searchResp.Data.TotalNumberOfItems == 0 || len(searchResp.Data.Items) == 0 {
			continue
		}
		item := searchResp.Data.Items[0]
		metadata := &core.ExtTrackMetadata{
			ID:         fmt.Sprintf("%d", item.ID),
			Name:       item.Title,
			Artists:    item.Artist.Name,
			AlbumName:  item.Album.Title,
			DurationMS: item.Duration * 1000,
			ISRC:       item.ISRC,
			TidalID:    fmt.Sprintf("%d", item.ID),
		}
		c.setCache(cacheKey, metadata, metadataTTL)
		return metadata, nil
	}
	return nil, fmt.Errorf("tidal_monochrome: ISRC %s not found on any server", isrc)
}

func (c *Client) SearchText(query string) (*core.ExtTrackMetadata, error) {
	cacheKey := "search:" + query
	if cached := c.getFromCache(cacheKey); cached != nil {
		return cached.(*core.ExtTrackMetadata), nil
	}

	baseURLs := c.getBaseURLs()
	for _, baseURL := range baseURLs {
		u := fmt.Sprintf("%s/search/?q=%s", baseURL, url.QueryEscape(query))
		resp, err := c.httpClient.Get(u)
		if err != nil {
			continue
		}
		body, readErr := io.ReadAll(resp.Body)
		resp.Body.Close()
		if readErr != nil || resp.StatusCode != http.StatusOK {
			continue
		}
		var searchResp searchResponse
		if err := json.Unmarshal(body, &searchResp); err != nil {
			continue
		}
		if searchResp.Data.TotalNumberOfItems == 0 || len(searchResp.Data.Items) == 0 {
			continue
		}
		item := searchResp.Data.Items[0]
		metadata := &core.ExtTrackMetadata{
			ID:         fmt.Sprintf("%d", item.ID),
			Name:       item.Title,
			Artists:    item.Artist.Name,
			AlbumName:  item.Album.Title,
			DurationMS: item.Duration * 1000,
			ISRC:       item.ISRC,
			TidalID:    fmt.Sprintf("%d", item.ID),
		}
		c.setCache(cacheKey, metadata, metadataTTL)
		return metadata, nil
	}
	return nil, fmt.Errorf("tidal_monochrome: no results for query %q", query)
}
