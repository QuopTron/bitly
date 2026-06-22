package deezer

import (
	"context"
	"fmt"
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
)

func (c *Client) GetRelatedArtists(ctx context.Context, artistID string, limit int) ([]core.SearchArtistResult, error) {
	normalized := strings.TrimSpace(strings.TrimPrefix(artistID, "deezer:"))
	if normalized == "" {
		return nil, fmt.Errorf("invalid Deezer artist ID")
	}
	if limit <= 0 {
		limit = 12
	}

	u := fmt.Sprintf("%s?limit=%d", fmt.Sprintf(artistRelatedURL, normalized), limit)
	var resp struct {
		Data  []deezerArtist `json:"data"`
		Error *struct {
			Type    string `json:"type"`
			Message string `json:"message"`
			Code    int    `json:"code"`
		} `json:"error,omitempty"`
	}
	if err := c.getJSON(ctx, u, &resp); err != nil {
		return nil, err
	}
	if resp.Error != nil {
		return nil, fmt.Errorf("deezer related artists error: %s", resp.Error.Message)
	}

	results := make([]core.SearchArtistResult, 0, len(resp.Data))
	for _, a := range resp.Data {
		image := a.PictureXL
		if image == "" {
			image = a.PictureBig
		}
		if image == "" {
			image = a.PictureMedium
		}
		if image == "" {
			image = a.Picture
		}
		results = append(results, core.SearchArtistResult{
			ID:     fmt.Sprintf("deezer:%d", a.ID),
			Name:   a.Name,
			Images: image,
		})
	}
	return results, nil
}

func (c *Client) GetArtistTopTracks(ctx context.Context, artistID string, limit int) ([]core.TrackMetadata, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	topURL := fmt.Sprintf("%s/artist/%s/top?limit=%d", baseURL, artistID, limit)
	var topResp struct {
		Data  []deezerTrack `json:"data"`
		Error *struct {
			Type    string `json:"type"`
			Message string `json:"message"`
			Code    int    `json:"code"`
		} `json:"error"`
	}
	if err := c.getJSON(ctx, topURL, &topResp); err != nil {
		return nil, fmt.Errorf("failed to fetch artist top tracks: %w", err)
	}
	if topResp.Error != nil {
		return nil, fmt.Errorf("deezer API error: %s (code %d)", topResp.Error.Message, topResp.Error.Code)
	}
	result := make([]core.TrackMetadata, 0, len(topResp.Data))
	for _, track := range topResp.Data {
		result = append(result, c.convertTrack(track))
	}
	return result, nil
}
