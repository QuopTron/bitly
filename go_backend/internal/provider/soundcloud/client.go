package soundcloud

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

const baseURL = "https://api-v2.soundcloud.com"

type Client struct {
	http     *http.Client
	clientID string
}

func NewClient(httpClient *http.Client, clientID string) *Client {
	if httpClient == nil {
		cfg := httpclient.DefaultConfig()
		cfg.Timeout = 15 * time.Second
		httpClient = httpclient.NewClient(cfg)
	}
	return &Client{http: httpClient, clientID: clientID}
}

func (c *Client) Name() string { return "soundcloud" }

type scTrack struct {
	ID          int64  `json:"id"`
	Title       string `json:"title"`
	Duration    int    `json:"duration"`
	Genre       string `json:"genre"`
	User        struct {
		ID       int64  `json:"id"`
		Username string `json:"username"`
	} `json:"user"`
	ArtworkURL string `json:"artwork_url"`
	StreamURL  string `json:"stream_url"`
}

func (c *Client) SearchTracks(query string, limit int) ([]provider.TrackResult, error) {
	if c.clientID == "" {
		return nil, fmt.Errorf("soundcloud: client_id not set")
	}
	if limit < 1 || limit > 100 {
		limit = 25
	}
	type searchResp struct {
		Collection []scTrack `json:"collection"`
	}
	var resp searchResp
	params := map[string]string{
		"q": query, "limit": fmt.Sprintf("%d", limit),
		"client_id": c.clientID,
	}
	if err := c.doGet("/search/tracks", params, &resp); err != nil {
		return nil, err
	}
	results := make([]provider.TrackResult, 0, len(resp.Collection))
	for _, t := range resp.Collection {
		results = append(results, provider.TrackResult{
			ID:       fmt.Sprintf("sc:%d", t.ID),
			Title:    t.Title,
			Artist:   t.User.Username,
			ArtistID: fmt.Sprintf("sc:%d", t.User.ID),
			Duration: t.Duration,
			CoverURL: t.ArtworkURL,
			Provider: "soundcloud",
		})
	}
	return results, nil
}

func (c *Client) doGet(path string, params map[string]string, result interface{}) error {
	u, _ := url.Parse(baseURL + path)
	q := u.Query()
	for k, v := range params {
		q.Set(k, v)
	}
	u.RawQuery = q.Encode()
	req, _ := http.NewRequest("GET", u.String(), nil)
	req.Header.Set("User-Agent", httpclient.RandomUserAgent())
	req.Header.Set("Accept", "application/json")
	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("soundcloud: HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}

	return json.NewDecoder(resp.Body).Decode(result)
}
