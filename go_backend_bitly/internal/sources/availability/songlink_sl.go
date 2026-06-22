package availability

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"

	httpclient "github.com/zarz/bitly/go_backend_bitly/internal/http"
)

func (s *Client) songLinkByURL(targetURL string) (map[string]platformLink, error) {
	httpclient.SongLinkRateLimiter.WaitForSlot()
	apiURL := fmt.Sprintf("%s?url=%s&userCountry=%s",
		songLinkURL, url.QueryEscape(targetURL), url.QueryEscape(GetRegion()))
	return s.doSLRequest(apiURL)
}

func (s *Client) songLinkByPlatform(platform, entityType, entityID string) (map[string]platformLink, error) {
	httpclient.SongLinkRateLimiter.WaitForSlot()
	apiURL := fmt.Sprintf("%s?platform=%s&type=%s&id=%s&userCountry=%s",
		songLinkURL, url.QueryEscape(platform), url.QueryEscape(entityType), url.QueryEscape(entityID), url.QueryEscape(GetRegion()))
	return s.doSLRequest(apiURL)
}

func (s *Client) doSLRequest(apiURL string) (map[string]platformLink, error) {
	req, err := http.NewRequest("GET", apiURL, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create SongLink request: %w", err)
	}

	config := httpclient.DefaultRetryConfig()
	resp, err := httpclient.DoWithRetry(s.client, req, config)
	if err != nil {
		return nil, fmt.Errorf("SongLink request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == 429 {
		return nil, fmt.Errorf("SongLink rate limit exceeded")
	}
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("SongLink returned status %d", resp.StatusCode)
	}

	body, err := httpclient.ReadResponseBody(resp)
	if err != nil {
		return nil, fmt.Errorf("failed to read SongLink response: %w", err)
	}

	var slResp struct {
		LinksByPlatform map[string]platformLink `json:"linksByPlatform"`
	}
	if err := json.Unmarshal(body, &slResp); err != nil {
		return nil, fmt.Errorf("failed to decode SongLink response: %w", err)
	}
	if len(slResp.LinksByPlatform) == 0 {
		return nil, fmt.Errorf("SongLink returned no platform links")
	}
	return slResp.LinksByPlatform, nil
}
