// Package qobuz implements a client for the Qobuz API.
package qobuz

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

const (
	baseURL    = "https://www.qobuz.com/api.json/0.2"
	appID      = "123456789" // placeholder, replaced by user
)

// Client is the Qobuz API client.
type Client struct {
	http     *http.Client
	appID    string
	userAuth *userAuth
	rate     *httpclient.RateLimiter
}

type userAuth struct {
	Token  string `json:"user_auth_token"`
	CredID string `json:"credential_id"`
}

// NewClient creates a Qobuz client. Pass empty strings for public-only access.
func NewClient(httpClient *http.Client, appID string) *Client {
	if httpClient == nil {
		cfg := httpclient.DefaultConfig()
		cfg.Timeout = 15 * time.Second
		httpClient = httpclient.NewClient(cfg)
	}
	if appID == "" {
		appID = "123456789" // placeholder, replaced by user
	}
	return &Client{
		http:  httpClient,
		appID: appID,
		rate: httpclient.NewRateLimiter(httpclient.RateLimitConfig{
			RequestsPerSecond: 5,
			Burst:             5,
		}),
	}
}

// Login authenticates with Qobuz credentials for stream URL access.
func (c *Client) Login(email, password string) error {
	data := url.Values{
		"email":    {email},
		"password": {password},
		"app_id":   {c.appID},
	}
	req, err := http.NewRequest("POST", baseURL+"/user/login", strings.NewReader(data.Encode()))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("User-Agent", httpclient.RandomUserAgent())
	req.Header.Set("X-App-Id", c.appID)

	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	var auth userAuth
	if err := json.NewDecoder(resp.Body).Decode(&auth); err != nil {
		return err
	}
	if auth.Token == "" {
		return fmt.Errorf("qobuz: login failed")
	}
	c.userAuth = &auth
	return nil
}

// Name returns "qobuz" for the provider registry.
func (c *Client) Name() string { return "qobuz" }

// doGet performs an authenticated GET to the Qobuz API.
func (c *Client) doGet(path string, params map[string]string, result interface{}) error {
	c.rate.Wait("qobuz.com")
	u, err := url.Parse(baseURL + path)
	if err != nil {
		return err
	}
	q := u.Query()
	q.Set("app_id", c.appID)
	for k, v := range params {
		q.Set(k, v)
	}
	u.RawQuery = q.Encode()

	req, err := http.NewRequest("GET", u.String(), nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", httpclient.RandomUserAgent())
	req.Header.Set("X-App-Id", c.appID)
	if c.userAuth != nil {
		req.Header.Set("X-User-Auth-Token", c.userAuth.Token)
	}

	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	return json.NewDecoder(resp.Body).Decode(result)
}
