package tidal

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
)

func (c *Client) GetTrackInfo(trackID string) (*core.ExtTrackMetadata, error) {
	cacheKey := "track:" + trackID
	if cached := c.getFromCache(cacheKey); cached != nil {
		return cached.(*core.ExtTrackMetadata), nil
	}

	baseURLs := c.getBaseURLs()
	for _, baseURL := range baseURLs {
		u := fmt.Sprintf("%s/info/?id=%s", baseURL, url.QueryEscape(trackID))
		resp, err := c.httpClient.Get(u)
		if err != nil {
			continue
		}
		body, readErr := io.ReadAll(resp.Body)
		resp.Body.Close()
		if readErr != nil || resp.StatusCode != http.StatusOK {
			continue
		}
		var infoResp infoResponse
		if err := json.Unmarshal(body, &infoResp); err != nil {
			continue
		}
		data := infoResp.Data
		metadata := &core.ExtTrackMetadata{
			ID:         fmt.Sprintf("%d", data.ID),
			Name:       data.Title,
			Artists:    data.Artist.Name,
			AlbumName:  data.Album.Title,
			DurationMS: data.Duration * 1000,
			ISRC:       data.ISRC,
			TidalID:    fmt.Sprintf("%d", data.ID),
		}
		c.setCache(cacheKey, metadata, metadataTTL)
		return metadata, nil
	}
	return nil, fmt.Errorf("tidal_monochrome: track %s not found", trackID)
}

func (c *Client) GetAlbum(albumID string) (*core.ExtAlbumMetadata, error) {
	cacheKey := "album:" + albumID
	if cached := c.getFromCache(cacheKey); cached != nil {
		return cached.(*core.ExtAlbumMetadata), nil
	}

	baseURLs := c.getBaseURLs()
	for _, baseURL := range baseURLs {
		u := fmt.Sprintf("%s/album/?id=%s", baseURL, url.QueryEscape(albumID))
		resp, err := c.httpClient.Get(u)
		if err != nil {
			continue
		}
		body, readErr := io.ReadAll(resp.Body)
		resp.Body.Close()
		if readErr != nil || resp.StatusCode != http.StatusOK {
			continue
		}
		var albumResp albumResponse
		if err := json.Unmarshal(body, &albumResp); err != nil {
			continue
		}
		data := albumResp.Data
		tracks := make([]core.ExtTrackMetadata, 0, len(data.Items))
		for _, item := range data.Items {
			tracks = append(tracks, core.ExtTrackMetadata{
				ID:          fmt.Sprintf("%d", item.Item.ID),
				Name:        item.Item.Title,
				Artists:     data.Artist.Name,
				AlbumName:   data.Title,
				DurationMS:  item.Item.Duration * 1000,
				ISRC:        item.Item.ISRC,
				TrackNumber: item.Item.TrackNumber,
				TidalID:     fmt.Sprintf("%d", item.Item.ID),
			})
		}

		coverURL := ""
		if data.Cover != "" {
			coverURL = fmt.Sprintf("https://resources.tidal.com/images/%s/640x640.jpg", data.Cover)
		}

		metadata := &core.ExtAlbumMetadata{
			ID:          fmt.Sprintf("%d", data.ID),
			Name:        data.Title,
			Artists:     data.Artist.Name,
			Tracks:      tracks,
			CoverURL:    coverURL,
			ReleaseDate: data.ReleaseDate,
			TotalTracks: data.NumberOfTracks,
		}
		c.setCache(cacheKey, metadata, metadataTTL)
		return metadata, nil
	}
	return nil, fmt.Errorf("tidal_monochrome: album %s not found", albumID)
}
