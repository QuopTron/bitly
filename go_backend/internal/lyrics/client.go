package lyrics

import (
	"fmt"
	"net/http"
	"time"
)

// Provider defines the interface for fetching lyrics.
type Provider interface {
	Name() string
	FetchLyrics(trackName, artistName string) (*Lyrics, error)
}

// Lyrics holds synced and plain lyrics.
type Lyrics struct {
	TrackName    string `json:"trackName"`
	ArtistName   string `json:"artistName"`
	PlainLyrics  string `json:"plainLyrics"`
	SyncedLyrics string `json:"syncedLyrics"`
	Source       string `json:"source"`
}

// Client fetches lyrics from multiple providers with fallback.
type Client struct {
	providers []Provider
	http      *http.Client
}

// NewClient creates a lyrics client with all available providers.
func NewClient(geniusToken ...string) *Client {
	c := &Client{
		http: &http.Client{Timeout: 10 * time.Second},
		providers: []Provider{
			&lrcLibProvider{http: &http.Client{Timeout: 10 * time.Second}},
		},
	}
	if len(geniusToken) > 0 && geniusToken[0] != "" {
		c.providers = append(c.providers, &geniusProvider{
			http:  &http.Client{Timeout: 10 * time.Second},
			token: geniusToken[0],
		})
	}
	return c
}

// SetGeniusToken adds or replaces the Genius provider.
func (c *Client) SetGeniusToken(token string) {
	if token == "" {
		return
	}
	for _, p := range c.providers {
		if p.Name() == "genius" {
			if gp, ok := p.(*geniusProvider); ok {
				gp.token = token
			}
			return
		}
	}
	c.providers = append(c.providers, &geniusProvider{
		http:  &http.Client{Timeout: 10 * time.Second},
		token: token,
	})
}

// GetLyrics tries all providers in order and returns the first match.
func (c *Client) GetLyrics(trackName, artistName string, durationMs int) (*Lyrics, error) {
	var lastErr error
	for _, p := range c.providers {
		lyrics, err := p.FetchLyrics(trackName, artistName)
		if err == nil && lyrics != nil && lyrics.PlainLyrics != "" {
			lyrics.TrackName = trackName
			lyrics.ArtistName = artistName
			return lyrics, nil
		}
		if err != nil {
			lastErr = err
		}
	}
	if lastErr != nil {
		return nil, lastErr
	}
	return nil, fmt.Errorf("lyrics: not found for %s - %s", trackName, artistName)
}
