package youtube

import (
	"fmt"
	"strings"
	"time"
)

func isRateLimitError(err error) bool {
	if err == nil {
		return false
	}
	errStr := err.Error()
	return strings.Contains(errStr, "429") || strings.Contains(errStr, "HTTP 429") || strings.Contains(errStr, "Too Many Requests")
}

func (c *Client) searchInnerTube(trackName, artistName string) (string, error) {
	searchQuery := artistName + " " + trackName
	fmt.Printf("[YTSearch] InnerTube searching: %s\n", searchQuery)

	if cached, ok := searchFailureCache.Load(searchQuery); ok {
		if entry, ok := cached.(searchFailureEntry); ok && time.Now().Before(entry.expiresAt) {
			fmt.Printf("[YTSearch] Skipping cached failed search for: %s\n", searchQuery)
			return "", fmt.Errorf("cached failure for %q", searchQuery)
		}
		searchFailureCache.Delete(searchQuery)
	}

	type result struct {
		url         string
		err         error
		rateLimited bool
	}

	done := make(chan result, 1)
	go func() {
		for _, sc := range searchClients {
			streamURL, err := c.searchInnerTubeClient(sc, searchQuery)
			if err == nil && streamURL != "" {
				fmt.Printf("[YTSearch] Found stream via %s\n", sc.Name)
				done <- result{url: streamURL}
				return
			}
			fmt.Printf("[YTSearch] %s failed: %v\n", sc.Name, err)
			if err != nil && isRateLimitError(err) {
				fmt.Printf("[YTSearch] Rate-limited on %s, stopping search\n", sc.Name)
				done <- result{err: fmt.Errorf("rate-limited: %w", err), rateLimited: true}
				return
			}
		}
		done <- result{err: fmt.Errorf("no video found for %q", searchQuery)}
	}()

	select {
	case r := <-done:
		if r.err != nil && (r.rateLimited || strings.Contains(r.err.Error(), "429")) {
			searchFailureCache.Store(searchQuery, searchFailureEntry{
				expiresAt: time.Now().Add(searchFailureCacheTTL),
			})
		}
		return r.url, r.err
	case <-time.After(globalSearchTimeout):
		searchFailureCache.Store(searchQuery, searchFailureEntry{
			expiresAt: time.Now().Add(searchFailureCacheTTL),
		})
		return "", fmt.Errorf("search timed out after %v", globalSearchTimeout)
	}
}
