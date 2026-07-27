// Package musicbrainz implements a client for the MusicBrainz API.
// Provides metadata lookup, ISRC resolution, and genre tagging.
package musicbrainz

import (
	"encoding/json"
	"net/http"
	"net/url"
	"time"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

const baseURL = "https://musicbrainz.org/ws/2"

// Client is the MusicBrainz API client.
type Client struct {
	http  *http.Client
	app   string
	limit *httpclient.RateLimiter
}

// NewClient creates a MusicBrainz client.
// appName is sent as User-Agent (required by MusicBrainz policy).
func NewClient(httpClient *http.Client, appName string) *Client {
	if httpClient == nil {
		cfg := httpclient.DefaultConfig()
		cfg.Timeout = 10 * time.Second
		httpClient = httpclient.NewClient(cfg)
	}
	if appName == "" {
		appName = "BitlyApp/1.0"
	}
	return &Client{
		http:  httpClient,
		app:   appName,
		limit: httpclient.NewRateLimiter(httpclient.RateLimitConfig{
			RequestsPerSecond: 1, // MusicBrainz requires 1 req/s
			Burst:             1,
		}),
	}
}

// Name returns "musicbrainz" for the provider registry.
func (c *Client) Name() string { return "musicbrainz" }

// doGet performs a rate-limited GET to the MusicBrainz API.
func (c *Client) doGet(path string, params map[string]string, result interface{}) error {
	c.limit.Wait("musicbrainz.org")

	u, _ := url.Parse(baseURL + path)
	q := u.Query()
	q.Set("fmt", "json")
	for k, v := range params {
		q.Set(k, v)
	}
	u.RawQuery = q.Encode()

	req, _ := http.NewRequest("GET", u.String(), nil)
	req.Header.Set("User-Agent", c.app)
	req.Header.Set("Accept", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	return json.NewDecoder(resp.Body).Decode(result)
}
