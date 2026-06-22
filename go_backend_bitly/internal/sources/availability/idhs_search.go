package availability

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"

	httpclient "github.com/zarz/bitly/go_backend_bitly/internal/http"
)

func (c *IDHSClient) Search(link string, adapters []string) (*IDHSSearchResponse, error) {
	idhsRateLimiter.WaitForSlot()

	reqBody := IDHSSearchRequest{
		Link:     link,
		Adapters: adapters,
	}

	jsonBody, err := json.Marshal(reqBody)
	if err != nil {
		return nil, fmt.Errorf("idhs: marshal request: %w", err)
	}

	req, err := http.NewRequest("POST", "https://idonthavespotify.sjdonado.com/api/search?v=1", bytes.NewBuffer(jsonBody))
	if err != nil {
		return nil, fmt.Errorf("idhs: create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", httpclient.UserAgentForURL(nil))

	resp, err := c.client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("idhs: request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == 400 {
		return nil, fmt.Errorf("idhs: invalid link or missing parameters")
	}
	if resp.StatusCode == 429 {
		return nil, fmt.Errorf("idhs: rate limit exceeded")
	}
	if resp.StatusCode == 500 {
		return nil, fmt.Errorf("idhs: processing failed")
	}
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("idhs: API returned status %d", resp.StatusCode)
	}

	body, err := httpclient.ReadResponseBody(resp)
	if err != nil {
		return nil, fmt.Errorf("idhs: read response: %w", err)
	}

	var result IDHSSearchResponse
	if err := json.Unmarshal(body, &result); err != nil {
		return nil, fmt.Errorf("idhs: decode response: %w", err)
	}

	return &result, nil
}
