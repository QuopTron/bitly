package musicbrainz

import (
	"fmt"
	"net/http"
	"time"

	httpclient "github.com/zarz/bitly/go_backend_bitly/internal/http"
)

func (c *Client) doRequest(reqURL string) (*http.Response, error) {
	c.waitForCooldown()
	c.rl.WaitForSlot()

	req, err := http.NewRequest(http.MethodGet, reqURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", userAgent)
	return httpclient.NewMetadataClient(10 * time.Second).Do(req)
}

func (c *Client) doRequestWithRetry(reqURL string) (*http.Response, error) {
	var resp *http.Response
	var lastErr error

	for attempt := 0; attempt < maxRetries; attempt++ {
		resp, lastErr = c.doRequest(reqURL)
		if lastErr != nil {
			if attempt < maxRetries-1 {
				time.Sleep(2 * time.Second)
			}
			continue
		}
		switch resp.StatusCode {
		case http.StatusOK:
			return resp, nil
		case http.StatusTooManyRequests, http.StatusServiceUnavailable:
			resp.Body.Close()
			c.enterCooldown()
			if attempt < maxRetries-1 {
				time.Sleep(cooldownDur)
			}
			continue
		default:
			resp.Body.Close()
			return nil, fmt.Errorf("MusicBrainz API returned status: %d", resp.StatusCode)
		}
	}

	if resp != nil {
		resp.Body.Close()
	}
	if lastErr != nil {
		return nil, fmt.Errorf("MusicBrainz request failed after %d attempts: %w", maxRetries, lastErr)
	}
	return nil, fmt.Errorf("MusicBrainz request failed after %d attempts", maxRetries)
}

func (c *Client) dedup(key inFlightKey, fn func() (string, error)) (string, error) {
	c.mu.Lock()
	if ch, exists := c.inflight[key]; exists {
		c.mu.Unlock()
		result := <-ch
		return result.result, result.err
	}

	ch := make(chan inFlightResult, 1)
	c.inflight[key] = ch
	c.mu.Unlock()

	var result inFlightResult
	result.result, result.err = fn()

	c.mu.Lock()
	delete(c.inflight, key)
	c.mu.Unlock()

	ch <- result
	return result.result, result.err
}
