package deezer

import (
	"crypto/md5"
	"encoding/hex"
	"fmt"
)

// GetTrack returns full track metadata by Deezer track ID.
func (c *Client) getTrackByID(trackID int64) (*Track, error) {
	var track Track
	if err := c.doGet(fmt.Sprintf("/track/%d", trackID), nil, &track); err != nil {
		return nil, err
	}
	return &track, nil
}

// getTrackByISRC looks up a track by its ISRC code using Deezer search.
func (c *Client) getTrackByISRC(isrc string) (*Track, error) {
	type searchResp struct {
		Data []Track `json:"data"`
	}
	var resp searchResp
	if err := c.doGet("/search/track", map[string]string{
		"q": fmt.Sprintf("isrc:\"%s\"", isrc), "limit": "1",
	}, &resp); err != nil {
		return nil, err
	}
	if len(resp.Data) == 0 {
		return nil, fmt.Errorf("deezer: no track found for ISRC %s", isrc)
	}
	return &resp.Data[0], nil
}

// calculateCDN determines the CDN server index from the MD5 hash.
func calculateCDN(md5Origin string) string {
	h := md5.Sum([]byte(md5Origin))
	hexStr := hex.EncodeToString(h[:])
	// Use first 2 hex chars as CDN index (0-255)
	idx := 0
	fmt.Sscanf(hexStr[:2], "%x", &idx)
	cdn := (idx % 3) + 1
	return fmt.Sprintf("%d", cdn)
}
