package lyrics

import (
	"fmt"
	"net/http"
	"strings"
	"time"
)

// Provider defines the interface for fetching lyrics.
type Provider interface {
	Name() string
	FetchLyrics(trackName, artistName string) (*Lyrics, error)
}

// DurationAwareProvider is an optional extension of Provider for sources that
// disambiguate better when they know the track duration (e.g. Apple Music's
// search scoring). The client prefers it when the caller has a duration.
type DurationAwareProvider interface {
	Provider
	FetchLyricsWithDuration(trackName, artistName string, durationMs int) (*Lyrics, error)
}

// FuncProvider adapts a plain function to the Provider interface so the
// extension runtime can register a lyrics source without the lyrics package
// importing it (avoids the import cycle).
type FuncProvider struct {
	name string
	fn   func(trackName, artistName string, durationMs int) (*Lyrics, error)
}

// NewFuncProvider wraps [fn] as a Provider named [name].
func NewFuncProvider(name string, fn func(trackName, artistName string, durationMs int) (*Lyrics, error)) *FuncProvider {
	return &FuncProvider{name: name, fn: fn}
}

func (f *FuncProvider) Name() string { return f.name }

// FetchLyrics satisfies Provider (duration unknown → 0).
func (f *FuncProvider) FetchLyrics(trackName, artistName string) (*Lyrics, error) {
	return f.fn(trackName, artistName, 0)
}

// FetchLyricsWithDuration satisfies DurationAwareProvider.
func (f *FuncProvider) FetchLyricsWithDuration(trackName, artistName string, durationMs int) (*Lyrics, error) {
	return f.fn(trackName, artistName, durationMs)
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

// AddProvider appends a provider to the fallback chain (used to register
// extension-backed lyrics sources after the built-in ones).
func (c *Client) AddProvider(p Provider) {
	c.providers = append(c.providers, p)
}

// GetLyrics tries all providers in order and returns the first match.
func (c *Client) GetLyrics(trackName, artistName string, durationMs int) (*Lyrics, error) {
	var lastErr error
	for _, p := range c.providers {
		var lyrics *Lyrics
		var err error
		if da, ok := p.(DurationAwareProvider); ok {
			lyrics, err = da.FetchLyricsWithDuration(trackName, artistName, durationMs)
		} else {
			lyrics, err = p.FetchLyrics(trackName, artistName)
		}
		// A provider "miss" (no lyrics found) is not an error worth keeping:
		// only transport/parse failures should shadow a later provider's hit.
		if err == nil && lyrics != nil && (lyrics.PlainLyrics != "" || lyrics.SyncedLyrics != "") {
			lyrics.TrackName = trackName
			lyrics.ArtistName = artistName
			return lyrics, nil
		}
		if err != nil && !strings.Contains(err.Error(), "no lyrics") &&
			!strings.Contains(err.Error(), "not found") {
			lastErr = err
		}
	}
	if lastErr != nil {
		return nil, lastErr
	}
	return nil, fmt.Errorf("lyrics: not found for %s - %s", trackName, artistName)
}
