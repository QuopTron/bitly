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

// GetTrackByISRC looks up a track by its ISRC code using Deezer search.
func (c *Client) getTrackByISRC(isrc string) (*Track, error) {
	results, err := c.searchTracks(fmt.Sprintf("isrc:\"%s\"", isrc), 1)
	if err != nil {
		return nil, err
	}
	if len(results) == 0 {
		return nil, fmt.Errorf("deezer: no track found for ISRC %s", isrc)
	}
	return c.getTrackByID(results[0].ID)
}

// GetStreamURL returns the stream URL for a Deezer track.
// Requires ARL to be set via SetARL.
//
// The URL is built using the MD5_ORIGIN field from the track metadata,
// which points to an encrypted audio stream on Deezer's CDN.
//
// Format: https://e-cdns-proxy-{cdn}.deezer.com/mobile/1/{md5_origin}
func (c *Client) getStreamURLByID(trackID int64) (string, error) {
	if c.arl == "" {
		return "", fmt.Errorf("deezer: ARL not set, cannot get stream URL")
	}
	track, err := c.getTrackByID(trackID)
	if err != nil {
		return "", err
	}
	if track.MD5Origin == "" {
		return "", fmt.Errorf("deezer: track %d has no MD5_ORIGIN", trackID)
	}
	cdn := calculateCDN(track.MD5Origin)
	return fmt.Sprintf("https://e-cdns-proxy-%s.deezer.com/mobile/1/%s", cdn, track.MD5Origin), nil
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
