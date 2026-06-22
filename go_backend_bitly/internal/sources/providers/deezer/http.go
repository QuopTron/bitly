package deezer

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

func (c *Client) getJSON(ctx context.Context, endpoint string, dst interface{}) error {
	var lastErr error
	for attempt := 0; attempt <= maxRetries; attempt++ {
		if attempt > 0 {
			delay := retryDelay * time.Duration(1<<(attempt-1))
			fmt.Printf("[Deezer] Retry %d/%d after %v...\n", attempt, maxRetries, delay)
			time.Sleep(delay)
		}
		err := c.doGetJSON(ctx, endpoint, dst)
		if err == nil {
			return nil
		}
		lastErr = err
		errStr := err.Error()
		isRetryable := strings.Contains(errStr, "timeout") ||
			strings.Contains(errStr, "connection reset") ||
			strings.Contains(errStr, "connection refused") ||
			strings.Contains(errStr, "EOF") ||
			strings.Contains(errStr, "status 5") ||
			strings.Contains(errStr, "status 429")
		if !isRetryable {
			return err
		}
		fmt.Printf("[Deezer] Attempt %d failed (retryable): %v\n", attempt+1, err)
	}
	return fmt.Errorf("all %d attempts failed: %w", maxRetries+1, lastErr)
}

func (c *Client) doGetJSON(ctx context.Context, endpoint string, dst interface{}) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Accept", "application/json")
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return err
	}
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("deezer API returned status %d: %s", resp.StatusCode, string(body))
	}
	return json.Unmarshal(body, dst)
}
