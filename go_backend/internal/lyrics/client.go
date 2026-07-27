package lyrics

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
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
	SyncedLyrics string `json:"syncedLyrics"` // LRC format
	Source       string `json:"source"`
}

// Client fetches lyrics from multiple providers with fallback.
type Client struct {
	providers []Provider
	http      *http.Client
}

// NewClient creates a lyrics client with all available providers.
// Optionally pass a Genius access token to enable Genius search.
func NewClient(geniusToken ...string) *Client {
	c := &Client{
		http: &http.Client{Timeout: 10 * time.Second},
		providers: []Provider{
			&lrcLibProvider{http: &http.Client{Timeout: 10 * time.Second}},
		},
	}
	// Add Genius if token is provided
	if len(geniusToken) > 0 && geniusToken[0] != "" {
		c.providers = append(c.providers, &geniusProvider{
			http:   &http.Client{Timeout: 10 * time.Second},
			token:  geniusToken[0],
		})
	}
	return c
}

// SetGeniusToken adds or replaces the Genius provider with the given token.
// Call this anytime after NewClient() to enable Genius searches.
func (c *Client) SetGeniusToken(token string) {
	if token == "" {
		return
	}
	// Look for existing genius provider and update token
	for _, p := range c.providers {
		if p.Name() == "genius" {
			if gp, ok := p.(*geniusProvider); ok {
				gp.token = token
			}
			return
		}
	}
	// Not found, add new genius provider
	c.providers = append(c.providers, &geniusProvider{
		http:  &http.Client{Timeout: 10 * time.Second},
		token: token,
	})
}

// GetLyrics tries all providers in order and returns the first match.
func (c *Client) GetLyrics(trackName, artistName string, durationMs int) (*Lyrics, error) {
	var lastErr error
	// Optionally pass duration hint to LRCLib
	for _, p := range c.providers {
		lyrics, err := p.FetchLyrics(trackName, artistName)
		if err == nil && lyrics != nil && lyrics.PlainLyrics != "" {
			lyrics.TrackName = trackName
			lyrics.ArtistName = artistName
			if durationMs > 0 && lyrics.SyncedLyrics == "" {
				// Duration hint available for future sync
			}
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

// --- LRCLib ---

type lrcLibProvider struct{ http *http.Client }

func (p *lrcLibProvider) Name() string { return "lrclib" }

func (p *lrcLibProvider) FetchLyrics(trackName, artistName string) (*Lyrics, error) {
	base := "https://lrclib.net/api"
	params := url.Values{}
	params.Set("track_name", trackName)
	params.Set("artist_name", artistName)

	resp, err := p.http.Get(base + "/get?" + params.Encode())
	if err != nil {
		return p.searchFallback(base, trackName, artistName)
	}
	defer resp.Body.Close()

	if resp.StatusCode == 404 {
		return p.searchFallback(base, trackName, artistName)
	}

	var lyrics Lyrics
	if err := json.NewDecoder(resp.Body).Decode(&lyrics); err != nil {
		return nil, err
	}
	lyrics.Source = "lrclib"
	return &lyrics, nil
}

func (p *lrcLibProvider) searchFallback(base, trackName, artistName string) (*Lyrics, error) {
	q := url.QueryEscape(trackName + " " + artistName)
	resp, err := p.http.Get(base + "/search?q=" + q)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var results []Lyrics
	if err := json.NewDecoder(resp.Body).Decode(&results); err != nil {
		return nil, err
	}
	if len(results) == 0 {
		return nil, fmt.Errorf("lrclib: not found")
	}
	lyrics := results[0]
	lyrics.Source = "lrclib"
	return &lyrics, nil
}

// --- Genius ---

type geniusProvider struct {
	http  *http.Client
	token string
}

func (p *geniusProvider) Name() string { return "genius" }

func (p *geniusProvider) FetchLyrics(trackName, artistName string) (*Lyrics, error) {
	q := url.QueryEscape(trackName + " " + artistName)
	searchURL := fmt.Sprintf("https://api.genius.com/search?q=%s", q)

	req, _ := http.NewRequest("GET", searchURL, nil)
	req.Header.Set("Authorization", "Bearer "+p.token)
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36")

	resp, err := p.http.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result struct {
		Response struct {
			Hits []struct {
				Result struct {
					ID    int    `json:"id"`
					Title string `json:"title"`
					URL   string `json:"url"`
				} `json:"result"`
			} `json:"hits"`
		} `json:"response"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	if len(result.Response.Hits) == 0 {
		return nil, fmt.Errorf("genius: not found")
	}

	plain, err := scrapeGeniusLyrics(p.http, result.Response.Hits[0].Result.URL)
	if err != nil {
		return nil, err
	}
	return &Lyrics{PlainLyrics: plain, Source: "genius"}, nil
}

func scrapeGeniusLyrics(client *http.Client, pageURL string) (string, error) {
	req, _ := http.NewRequest("GET", pageURL, nil)
	req.Header.Set("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")

	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	html := string(body)

	start := strings.Index(html, `data-lyrics-container="true"`)
	if start < 0 {
		return "", fmt.Errorf("genius: container not found")
	}
	containerStart := strings.Index(html[start:], ">")
	if containerStart < 0 {
		return "", fmt.Errorf("genius: no content")
	}
	contentStart := start + containerStart + 1
	contentEnd := strings.Index(html[contentStart:], "</div>")
	if contentEnd < 0 {
		return "", fmt.Errorf("genius: no end div")
	}

	raw := html[contentStart : contentStart+contentEnd]
	raw = strings.ReplaceAll(raw, "<br/>", "\n")
	raw = strings.ReplaceAll(raw, "<br>", "\n")
	raw = strings.ReplaceAll(raw, "&amp;", "&")
	raw = strings.ReplaceAll(raw, "&quot;", "\"")
	raw = stripHTMLTags(raw)
	return strings.TrimSpace(raw), nil
}

func stripHTMLTags(s string) string {
	var b strings.Builder
	inTag := false
	for _, r := range s {
		if r == '<' {
			inTag = true
			continue
		}
		if r == '>' {
			inTag = false
			continue
		}
		if !inTag {
			b.WriteRune(r)
		}
	}
	return b.String()
}
