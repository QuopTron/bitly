package availability

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"

	httpclient "github.com/zarz/bitly/go_backend_bitly/internal/http"
)

func isSpotifyURL(u string) bool {
	lower := strings.ToLower(u)
	return strings.Contains(lower, "spotify.com/") || strings.Contains(lower, "spotify:")
}

func (s *Client) resolve(inputURL string) (map[string]platformLink, error) {
	if isSpotifyURL(inputURL) {
		payload, _ := json.Marshal(map[string]string{"url": inputURL})
		links, err := s.doResolve(payload)
		if err == nil {
			return links, nil
		}
		fmt.Printf("[SongLink] Resolve proxy failed for %s: %v, falling back to SongLink\n", inputURL, err)
		return s.songLinkByURL(inputURL)
	}
	return s.songLinkByURL(inputURL)
}

func (s *Client) resolveByPlatform(platform, entityType, entityID string) (map[string]platformLink, error) {
	if strings.EqualFold(platform, "spotify") {
		payload, _ := json.Marshal(map[string]string{
			"platform": platform,
			"type":     entityType,
			"id":       entityID,
		})
		links, err := s.doResolve(payload)
		if err == nil {
			return links, nil
		}
		fmt.Printf("[SongLink] Resolve proxy failed for %s/%s/%s: %v, falling back\n", platform, entityType, entityID, err)
		return s.songLinkByPlatform(platform, entityType, entityID)
	}
	return s.songLinkByPlatform(platform, entityType, entityID)
}

func (s *Client) doResolve(payload []byte) (map[string]platformLink, error) {
	req, err := http.NewRequest("POST", resolveAPIURL, bytes.NewReader(payload))
	if err != nil {
		return nil, fmt.Errorf("failed to create resolve request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := s.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("resolve API request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("resolve API returned status %d", resp.StatusCode)
	}

	body, err := httpclient.ReadResponseBody(resp)
	if err != nil {
		return nil, fmt.Errorf("failed to read resolve response: %w", err)
	}

	var resolveResp struct {
		Success  bool                       `json:"success"`
		ISRC     string                     `json:"isrc"`
		SongUrls map[string]json.RawMessage `json:"songUrls"`
	}
	if err := json.Unmarshal(body, &resolveResp); err != nil {
		return nil, fmt.Errorf("failed to decode resolve response: %w", err)
	}
	if !resolveResp.Success {
		return nil, fmt.Errorf("resolve API returned success=false")
	}

	keyMap := map[string]string{
		"Spotify":      "spotify",
		"Deezer":       "deezer",
		"Tidal":        "tidal",
		"YouTubeMusic": "youtubeMusic",
		"YouTube":      "youtube",
		"AmazonMusic":  "amazonMusic",
		"Qobuz":        "qobuz",
		"AppleMusic":   "appleMusic",
	}

	links := make(map[string]platformLink)
	for resolveKey, platformKey := range keyMap {
		rawValue, ok := resolveResp.SongUrls[resolveKey]
		if !ok {
			continue
		}
		if u := extractURL(rawValue); u != "" {
			links[platformKey] = platformLink{URL: u}
		}
	}

	if len(links) == 0 {
		return nil, fmt.Errorf("resolve API returned no platform links")
	}
	return links, nil
}

func extractURL(raw json.RawMessage) string {
	trimmed := bytes.TrimSpace(raw)
	if len(trimmed) == 0 || bytes.Equal(trimmed, []byte("null")) {
		return ""
	}
	var direct string
	if err := json.Unmarshal(trimmed, &direct); err == nil {
		return strings.TrimSpace(direct)
	}
	var list []string
	if err := json.Unmarshal(trimmed, &list); err == nil {
		for _, c := range list {
			if cleaned := strings.TrimSpace(c); cleaned != "" {
				return cleaned
			}
		}
	}
	return ""
}
