// Package tidal implements a client for the Tidal API.
package tidal

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

const baseURL = "https://api.tidal.com/v1"

// Client is the Tidal API client.
type Client struct {
	http      *http.Client
	clientID  string
	token     string
}

// NewClient creates a Tidal client. Pass an empty token for public-only access
// (search works, but stream URLs require authentication).
func NewClient(httpClient *http.Client, clientID, token string) *Client {
	if httpClient == nil {
		cfg := httpclient.DefaultConfig()
		cfg.Timeout = 15 * time.Second
		httpClient = httpclient.NewClient(cfg)
	}
	if clientID == "" {
		clientID = "zU4XHVVq0I" // Tidal's public client ID
	}
	return &Client{
		http:     httpClient,
		clientID: clientID,
		token:    token,
	}
}

// SetToken sets the Tidal access token for authenticated requests.
func (c *Client) SetToken(token string) {
	c.token = token
}

// Name returns "tidal" for the provider registry.
func (c *Client) Name() string { return "tidal" }

// doGet performs a GET to the Tidal API.
func (c *Client) doGet(path string, params map[string]string, result interface{}) error {
	u, err := url.Parse(baseURL + path)
	if err != nil {
		return err
	}
	q := u.Query()
	q.Set("countryCode", "US")
	q.Set("limit", "50")
	for k, v := range params {
		q.Set(k, v)
	}
	u.RawQuery = q.Encode()

	req, err := http.NewRequest("GET", u.String(), nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", httpclient.RandomUserAgent())
	req.Header.Set("X-Tidal-Token", c.clientID)
	if c.token != "" {
		req.Header.Set("Authorization", "Bearer "+c.token)
	}

	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("tidal: HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}

	return json.NewDecoder(resp.Body).Decode(result)
}
