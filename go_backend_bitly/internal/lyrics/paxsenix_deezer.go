package lyrics

import (
	"fmt"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/http"
)

type DeezerLyricsClient struct {
	httpClient *http.Client
}

func NewDeezerLyricsClient() *DeezerLyricsClient {
	return &DeezerLyricsClient{httpClient: httpclient.NewMetadataClient(15 * time.Second)}
}

func normalizeDeezerLyricsID(raw string) string {
	raw = strings.TrimSpace(raw)
	if strings.HasPrefix(strings.ToLower(raw), "deezer:") {
		raw = strings.TrimSpace(raw[len("deezer:"):])
	}
	// Strip query params first
	raw = strings.Split(raw, "?")[0]
	if strings.Contains(raw, "deezer.com/") {
		parts := strings.Split(raw, "/")
		last := parts[len(parts)-1]
		if _, err := strconv.ParseInt(last, 10, 64); err == nil {
			raw = last
		}
	}
	raw = strings.TrimSpace(raw)
	if _, err := strconv.ParseInt(raw, 10, 64); err == nil {
		return raw
	}
	return ""
}

func (c *DeezerLyricsClient) fetchLyricsByID(trackID string, multiPersonWordByWord bool) (*LyricsResponse, error) {
	params := url.Values{}
	params.Set("id", trackID)
	raw, err := fetchPaxsenixBody(c.httpClient, "https://lyrics.paxsenix.org/deezer/lyrics", params)
	if err != nil {
		return nil, fmt.Errorf("deezer lyrics fetch failed: %w", err)
	}
	return parsePaxsenixLyricsPayload(raw, "Deezer", multiPersonWordByWord)
}

func (c *DeezerLyricsClient) FetchLyrics(spotifyID, trackName, artistName string, durationSec float64) (*LyricsResponse, error) {
	deezerID := normalizeDeezerLyricsID(spotifyID)
	if deezerID == "" {
		return nil, fmt.Errorf("deezer provider needs a deezer id or spotify id")
	}
	return c.fetchLyricsByID(deezerID, true)
}
