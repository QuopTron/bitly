package deezer

import (
	"context"
	"fmt"
	"net/url"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
)

func (c *Client) searchTracks(ctx context.Context, query string, limit int) ([]deezerTrack, error) {
	u := fmt.Sprintf("%s/track?q=%s&limit=%d", searchURL, url.QueryEscape(query), limit)
	var resp struct {
		Data  []deezerTrack `json:"data"`
		Error *struct {
			Type    string `json:"type"`
			Message string `json:"message"`
			Code    int    `json:"code"`
		} `json:"error"`
	}
	if err := c.getJSON(ctx, u, &resp); err != nil {
		return nil, err
	}
	if resp.Error != nil {
		return nil, fmt.Errorf("deezer API error: %s (code %d)", resp.Error.Message, resp.Error.Code)
	}
	return resp.Data, nil
}

func (c *Client) searchArtists(ctx context.Context, query string, limit int) ([]core.SearchArtistResult, error) {
	u := fmt.Sprintf("%s/artist?q=%s&limit=%d", searchURL, url.QueryEscape(query), limit)
	var resp struct {
		Data  []deezerArtist `json:"data"`
		Error *struct {
			Type    string `json:"type"`
			Message string `json:"message"`
			Code    int    `json:"code"`
		} `json:"error"`
	}
	if err := c.getJSON(ctx, u, &resp); err != nil {
		return nil, err
	}
	if resp.Error != nil || len(resp.Data) == 0 {
		return nil, fmt.Errorf("no artists found or API error")
	}
	results := make([]core.SearchArtistResult, 0, len(resp.Data))
	for _, a := range resp.Data {
		results = append(results, core.SearchArtistResult{
			ID:     fmt.Sprintf("deezer:%d", a.ID),
			Name:   a.Name,
			Images: c.bestArtistImage(a),
		})
	}
	return results, nil
}
