package deezer

import (
	"context"
	"fmt"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
)

func (c *Client) GetTrack(ctx context.Context, trackID string) (*core.TrackResponse, error) {
	u := fmt.Sprintf(trackURL, trackID)
	var track deezerTrack
	if err := c.getJSON(ctx, u, &track); err != nil {
		return nil, err
	}
	converted := c.convertTrack(track)
	return &core.TrackResponse{Track: converted}, nil
}

func (c *Client) GetTrackISRC(ctx context.Context, trackID string) (string, error) {
	c.cacheMu.RLock()
	if isrc, ok := c.isrcCache[trackID]; ok {
		c.cacheMu.RUnlock()
		return isrc, nil
	}
	c.cacheMu.RUnlock()

	fullTrack, err := c.fetchFullTrack(ctx, trackID)
	if err != nil {
		return "", err
	}
	c.cacheMu.Lock()
	c.isrcCache[trackID] = fullTrack.ISRC
	c.maybeCleanupCachesLocked(time.Now())
	c.cacheMu.Unlock()
	return fullTrack.ISRC, nil
}

func (c *Client) fetchFullTrack(ctx context.Context, trackID string) (*deezerTrack, error) {
	u := fmt.Sprintf(trackURL, trackID)
	var track deezerTrack
	if err := c.getJSON(ctx, u, &track); err != nil {
		return nil, err
	}
	return &track, nil
}

func (c *Client) SearchByISRC(ctx context.Context, isrc string) (*core.TrackMetadata, error) {
	directURL := fmt.Sprintf("%s/track/isrc:%s", baseURL, isrc)
	var track deezerTrack
	if err := c.getJSON(ctx, directURL, &track); err != nil || track.ID == 0 {
		searchURL := fmt.Sprintf("%s/track?q=isrc:%s&limit=1", searchURL, isrc)
		var resp struct {
			Data []deezerTrack `json:"data"`
		}
		if err := c.getJSON(ctx, searchURL, &resp); err != nil {
			return nil, err
		}
		if len(resp.Data) == 0 {
			return nil, fmt.Errorf("no track found for ISRC: %s", isrc)
		}
		result := c.convertTrack(resp.Data[0])
		return &result, nil
	}
	if track.ID == 0 {
		return nil, fmt.Errorf("no track found for ISRC: %s", isrc)
	}
	result := c.convertTrack(track)
	return &result, nil
}
