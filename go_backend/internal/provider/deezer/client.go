// Package deezer implements a built-in Deezer client for metadata lookup,
// search, and stream URL retrieval via the public Deezer API.
package deezer

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

// Client is the Deezer API client.
type Client struct {
	http   *http.Client
	base   string
	arl    string
	rate   *httpclient.RateLimiter
}

// NewClient creates a Deezer client with the given HTTP client.
// If httpClient is nil, a default one is created.
func NewClient(httpClient *http.Client) *Client {
	if httpClient == nil {
		cfg := httpclient.DefaultConfig()
		cfg.Timeout = 15 * time.Second
		httpClient = httpclient.NewClient(cfg)
	}
	return &Client{
		http: httpClient,
		base: "https://api.deezer.com",
		rate: httpclient.NewRateLimiter(httpclient.RateLimitConfig{
			RequestsPerSecond: 5,
			Burst:             5,
		}),
	}
}

// Name returns "deezer" for the provider registry.
func (c *Client) Name() string { return "deezer" }

// SetARL sets the Deezer ARL cookie for authenticated requests (stream URLs).
func (c *Client) SetARL(arl string) {
	c.arl = arl
}

// doGet performs a GET to the Deezer API and decodes the JSON response.
func (c *Client) doGet(path string, params map[string]string, result interface{}) error {
	c.rate.Wait("api.deezer.com")

	u, err := url.Parse(c.base + path)
	if err != nil {
		return err
	}
	q := u.Query()
	for k, v := range params {
		q.Set(k, v)
	}
	u.RawQuery = q.Encode()

	req, err := http.NewRequest("GET", u.String(), nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", httpclient.RandomUserAgent())
	req.Header.Set("Accept", "application/json")

	if c.arl != "" {
		req.Header.Set("Cookie", "arl="+c.arl)
	}

	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("deezer: HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}

	return json.NewDecoder(resp.Body).Decode(result)
}
