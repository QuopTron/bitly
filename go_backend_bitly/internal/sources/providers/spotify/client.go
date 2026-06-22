package spotify

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

const spotifyAPIBase = "https://api.spotify.com/v1"

// Client communicates with the Spotify API (for metadata only).
type Client struct {
	httpClient *http.Client
	authToken  string
}

// NewClient creates a new Spotify client.
func NewClient() *Client {
	return &Client{
		httpClient: &http.Client{
			Timeout: 15 * time.Second,
		},
	}
}

// SetAuthToken sets the Bearer token for API requests.
func (c *Client) SetAuthToken(token string) {
	c.authToken = token
}

// GetTrackMetadata fetches track metadata from Spotify.
func (c *Client) GetTrackMetadata(trackID string) (interface{}, error) {
	if c.authToken == "" {
		return nil, fmt.Errorf("spotify: no auth token set")
	}
	req, err := http.NewRequest("GET", fmt.Sprintf("%s/tracks/%s", spotifyAPIBase, trackID), nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Authorization", "Bearer "+c.authToken)
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("spotify: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("spotify: HTTP %d", resp.StatusCode)
	}
	var result map[string]interface{}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	return result, nil
}
