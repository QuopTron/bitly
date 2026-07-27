// Package lyrics fetches song lyrics from LRCLib and other providers.
package lyrics

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"time"
)

// Lyrics holds synced and plain lyrics.
type Lyrics struct {
	TrackName   string `json:"trackName"`
	ArtistName  string `json:"artistName"`
	PlainLyrics string `json:"plainLyrics"`
	SyncedLyrics string `json:"syncedLyrics"` // LRC format
	Source      string `json:"source"`
}

// Client fetches lyrics from LRCLib.
type Client struct {
	http   *http.Client
	base   string
}

// NewClient creates a lyrics client using the public LRCLib API.
func NewClient() *Client {
	return &Client{
		http: &http.Client{Timeout: 10 * time.Second},
		base: "https://lrclib.net/api",
	}
}

// GetLyrics fetches lyrics for a track, optionally with duration hint.
func (c *Client) GetLyrics(trackName, artistName string, durationMs int) (*Lyrics, error) {
	params := url.Values{}
	params.Set("track_name", trackName)
	params.Set("artist_name", artistName)
	if durationMs > 0 {
		params.Set("duration", fmt.Sprintf("%d", durationMs/1000))
	}

	resp, err := c.http.Get(c.base + "/get?" + params.Encode())
	if err != nil {
		return c.fallbackSearch(trackName, artistName)
	}
	defer resp.Body.Close()

	if resp.StatusCode == 404 {
		return c.fallbackSearch(trackName, artistName)
	}

	var lyrics Lyrics
	if err := json.NewDecoder(resp.Body).Decode(&lyrics); err != nil {
		return nil, err
	}
	lyrics.Source = "lrclib"
	return &lyrics, nil
}

// fallbackSearch tries searching by query when direct lookup fails.
func (c *Client) fallbackSearch(trackName, artistName string) (*Lyrics, error) {
	query := url.QueryEscape(fmt.Sprintf("%s %s", trackName, artistName))
	resp, err := c.http.Get(c.base + "/search?q=" + query)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var results []Lyrics
	if err := json.NewDecoder(resp.Body).Decode(&results); err != nil {
		return nil, err
	}
	if len(results) == 0 {
		return nil, fmt.Errorf("lyrics: not found for %s - %s", trackName, artistName)
	}

	lyrics := results[0]
	lyrics.Source = "lrclib"
	return &lyrics, nil
}
