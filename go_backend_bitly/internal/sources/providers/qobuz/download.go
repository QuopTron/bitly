package qobuz

import (
	"encoding/json"
	"fmt"
	"strings"
)

func (c *Client) DownloadURL(trackID string, quality string) (string, error) {
	cacheKey := "dl:" + trackID + ":" + quality
	if cached := c.getFromCache(cacheKey); cached != nil {
		return cached.(string), nil
	}

	q := quality
	if q == "" {
		q = "27"
	}

	data, err := c.getJSON("/download-music", map[string]string{
		"track_id": trackID,
		"quality":  q,
	})
	if err != nil {
		return "", fmt.Errorf("qobuz_kennyy download: %w", err)
	}

	var dlData downloadData
	if err := json.Unmarshal(data, &dlData); err != nil {
		return "", fmt.Errorf("qobuz_kennyy parse download: %w", err)
	}
	if dlData.URL == "" {
		return "", fmt.Errorf("qobuz_kennyy: no download URL returned")
	}

	c.setCache(cacheKey, dlData.URL, downloadCacheTTL)
	return dlData.URL, nil
}

func QualityToParam(quality string) string {
	switch strings.ToUpper(quality) {
	case "MP3_320", "320":
		return "5"
	case "LOSSLESS", "CD", "16":
		return "6"
	case "HI_RES", "24":
		return "7"
	default:
		return "27"
	}
}
