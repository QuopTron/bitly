package tidal

import (
	"encoding/json"
	"io"
	"strings"
	"time"
)

func (c *Client) periodicRefresh() {
	ticker := time.NewTicker(10 * time.Minute)
	for range ticker.C {
		c.refreshServers()
	}
}

func (c *Client) refreshServers() {
	uptimeURLs := []string{
		"https://tidal-uptime.jiffy-puffs-1j.workers.dev",
		"https://tidal-uptime.props-76styles.workers.dev",
	}
	seen := map[string]struct{}{}
	var servers []server

	for _, uptimeURL := range uptimeURLs {
		resp, err := c.httpClient.Get(uptimeURL)
		if err != nil {
			continue
		}
		body, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			continue
		}
		var uptime uptimeResponse
		if err := json.Unmarshal(body, &uptime); err != nil {
			continue
		}
		for _, api := range uptime.API {
			normalized := strings.TrimRight(api.URL, "/")
			if _, exists := seen[normalized]; !exists {
				seen[normalized] = struct{}{}
				servers = append(servers, api)
			}
		}
	}

	if len(servers) == 0 {
		servers = []server{
			{URL: "https://eu-central.monochrome.tf", Version: "2.10"},
			{URL: "https://us-west.monochrome.tf", Version: "2.10"},
			{URL: "https://api.monochrome.tf", Version: "2.5"},
		}
	}

	c.mu.Lock()
	c.baseURLs = make([]string, len(servers))
	for i, s := range servers {
		c.baseURLs[i] = strings.TrimRight(s.URL, "/")
	}
	c.mu.Unlock()
}

func (c *Client) getBaseURLs() []string {
	c.mu.RLock()
	defer c.mu.RUnlock()
	result := make([]string, len(c.baseURLs))
	copy(result, c.baseURLs)
	return result
}

func (c *Client) getFromCache(key string) interface{} {
	c.mu.RLock()
	defer c.mu.RUnlock()
	entry, ok := c.cache[key]
	if !ok || time.Now().After(entry.expiresAt) {
		return nil
	}
	return entry.data
}

func (c *Client) setCache(key string, data interface{}, ttl time.Duration) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.cache[key] = &cacheEntry{data: data, expiresAt: time.Now().Add(ttl)}
}
