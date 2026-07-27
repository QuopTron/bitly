// Package spotify implements a client for the Spotify Web API.
// Note: Spotify does not provide download/stream URLs — this is for
// metadata lookup and search only.
package spotify

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

const baseURL = "https://api.spotify.com/v1"

// Client is the Spotify API client.
type Client struct {
	http         *http.Client
	clientID     string
	clientSecret string
	token        string
	tokenExp     time.Time
	mu           sync.Mutex
}

// NewClient creates a Spotify client with OAuth app credentials.
func NewClient(httpClient *http.Client, clientID, clientSecret string) *Client {
	if httpClient == nil {
		cfg := httpclient.DefaultConfig()
		cfg.Timeout = 15 * time.Second
		httpClient = httpclient.NewClient(cfg)
	}
	return &Client{
		http:         httpClient,
		clientID:     clientID,
		clientSecret: clientSecret,
	}
}

// ensureToken obtains a fresh OAuth token if expired.
func (c *Client) ensureToken() error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if c.token != "" && time.Now().Before(c.tokenExp) {
		return nil
	}
	data := url.Values{
		"grant_type": {"client_credentials"},
	}
	req, err := http.NewRequest("POST", "https://accounts.spotify.com/api/token",
		strings.NewReader(data.Encode()))
	if err != nil {
		return err
	}
	req.SetBasicAuth(c.clientID, c.clientSecret)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	var tokenResp struct {
		AccessToken string `json:"access_token"`
		TokenType   string `json:"token_type"`
		ExpiresIn   int    `json:"expires_in"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&tokenResp); err != nil {
		return err
	}
	c.token = tokenResp.AccessToken
	c.tokenExp = time.Now().Add(time.Duration(tokenResp.ExpiresIn-60) * time.Second)
	return nil
}

// Name returns "spotify" for the provider registry.
func (c *Client) Name() string { return "spotify" }

// doGet performs an authenticated GET to the Spotify API.
func (c *Client) doGet(path string, params map[string]string, result interface{}) error {
	if err := c.ensureToken(); err != nil {
		return err
	}
	u, _ := url.Parse(baseURL + path)
	q := u.Query()
	for k, v := range params {
		q.Set(k, v)
	}
	u.RawQuery = q.Encode()

	req, _ := http.NewRequest("GET", u.String(), nil)
	req.Header.Set("Authorization", "Bearer "+c.token)

	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := io.ReadAll(resp.Body)
		if resp.StatusCode == 401 {
			c.mu.Lock()
			c.token = ""
			c.mu.Unlock()
			return c.doGet(path, params, result)
		}
		return fmt.Errorf("spotify: HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}
	return json.NewDecoder(resp.Body).Decode(result)
}
