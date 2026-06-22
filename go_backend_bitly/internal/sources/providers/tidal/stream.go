package tidal

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
)

func (c *Client) GetTrackStreamURL(trackID string) (string, error) {
	baseURLs := c.getBaseURLs()
	for _, baseURL := range baseURLs {
		u := fmt.Sprintf("%s/track/%s", baseURL, url.PathEscape(trackID))
		resp, err := c.httpClient.Get(u)
		if err != nil {
			continue
		}
		body, readErr := io.ReadAll(resp.Body)
		resp.Body.Close()
		if readErr != nil || resp.StatusCode != http.StatusOK {
			continue
		}
		var streamResp streamResponse
		if err := json.Unmarshal(body, &streamResp); err != nil {
			continue
		}
		if streamResp.Data.URL != "" {
			fmt.Printf("[TidalMonochrome] Got stream URL for track %s (codec=%s, quality=%s)\n",
				trackID, streamResp.Data.Codec, streamResp.Data.AudioQuality)
			return streamResp.Data.URL, nil
		}
	}
	return "", fmt.Errorf("tidal_monochrome: no stream URL for track %s", trackID)
}
