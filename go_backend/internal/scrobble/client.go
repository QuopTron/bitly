// Package scrobble sends playback data to Last.fm and ListenBrainz.
package scrobble

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// Track holds playback data to scrobble.
type Track struct {
	TrackName  string `json:"trackName"`
	ArtistName string `json:"artistName"`
	AlbumName  string `json:"albumName"`
	DurationMs int    `json:"durationMs"`
	Timestamp  int64  `json:"timestamp"`
}

// Client manages scrobbling to multiple services.
type Client struct {
	lastfmKey string
	lastfmSecret string
	lbToken   string
	http      *http.Client
}

// NewClient creates a scrobble client.
func NewClient(lastfmAPIKey, lastfmSecret, listenBrainzToken string) *Client {
	return &Client{
		lastfmKey:    lastfmAPIKey,
		lastfmSecret: lastfmSecret,
		lbToken:      listenBrainzToken,
		http:         &http.Client{Timeout: 10 * time.Second},
	}
}

// ScrobbleLastFM sends a scrobble to Last.fm.
func (c *Client) ScrobbleLastFM(track Track, sessionKey string) error {
	if c.lastfmKey == "" || sessionKey == "" {
		return fmt.Errorf("scrobble: last.fm not configured")
	}
	data := url.Values{
		"method":       {"track.scrobble"},
		"api_key":      {c.lastfmKey},
		"sk":           {sessionKey},
		"track":        {track.TrackName},
		"artist":       {track.ArtistName},
		"album":        {track.AlbumName},
		"timestamp":    {fmt.Sprintf("%d", track.Timestamp)},
		"duration":     {fmt.Sprintf("%d", track.DurationMs/1000)},
		"format":       {"json"},
	}
	req, _ := http.NewRequest("POST", "https://ws.audioscrobbler.com/2.0/",
		strings.NewReader(data.Encode()))
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	return nil
}

// ScrobbleListenBrainz sends a listen to ListenBrainz.
func (c *Client) ScrobbleListenBrainz(track Track) error {
	if c.lbToken == "" {
		return fmt.Errorf("scrobble: listenbrainz not configured")
	}
	payload := map[string]interface{}{
		"listen_type": "single",
		"payload": []map[string]interface{}{
			{
				"track_metadata": map[string]interface{}{
					"artist_name": track.ArtistName,
					"track_name":  track.TrackName,
					"release_name": track.AlbumName,
					"additional_info": map[string]interface{}{
						"duration_ms": track.DurationMs,
					},
				},
				"listened_at": track.Timestamp,
			},
		},
	}
	body, _ := json.Marshal(payload)
	req, _ := http.NewRequest("POST", "https://api.listenbrainz.org/1/submit-listens",
		strings.NewReader(string(body)))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Token "+c.lbToken)

	resp, err := c.http.Do(req)
	if err != nil {
		return err
	}
	resp.Body.Close()
	return nil
}
