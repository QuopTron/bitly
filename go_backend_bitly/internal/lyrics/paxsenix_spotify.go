package lyrics

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"regexp"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/http"
)

type SpotifyLyricsClient struct {
	httpClient *http.Client
}

type spotifyLyricsSearchResult struct {
	TrackID    string `json:"trackId"`
	Name       string `json:"name"`
	ArtistName string `json:"artistName"`
	Duration   string `json:"duration"`
}

func NewSpotifyLyricsClient() *SpotifyLyricsClient {
	return &SpotifyLyricsClient{httpClient: httpclient.NewMetadataClient(15 * time.Second)}
}

var regexpSpotifyTrackID = regexp.MustCompile(`^[A-Za-z0-9]{22}$`)

func normalizeSpotifyLyricsID(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" || strings.HasPrefix(strings.ToLower(raw), "deezer:") {
		return ""
	}
	if strings.HasPrefix(strings.ToLower(raw), "spotify:") {
		parts := strings.Split(raw, ":")
		raw = parts[len(parts)-1]
	}
	if strings.Contains(raw, "spotify.com/track/") {
		if idx := strings.Index(raw, "spotify.com/track/"); idx >= 0 {
			raw = raw[idx+len("spotify.com/track/"):]
		}
	}
	raw = strings.TrimSpace(strings.Split(raw, "?")[0])
	if regexpSpotifyTrackID.MatchString(raw) {
		return raw
	}
	return ""
}

func (c *SpotifyLyricsClient) searchSong(trackName, artistName string, durationSec float64) (string, error) {
	query := strings.TrimSpace(trackName + " " + artistName)
	if query == "" {
		return "", fmt.Errorf("empty search query")
	}
	params := url.Values{}
	params.Set("q", query)
	raw, err := fetchPaxsenixBody(c.httpClient, "https://lyrics.paxsenix.org/spotify/search", params)
	if err != nil {
		return "", fmt.Errorf("spotify search failed: %w", err)
	}

	var results []spotifyLyricsSearchResult
	if err := json.Unmarshal([]byte(raw), &results); err != nil {
		return "", fmt.Errorf("failed to decode spotify search: %w", err)
	}
	best := selectBestSpotifyLyricsSearchResult(results, trackName, artistName, durationSec)
	if best == nil || strings.TrimSpace(best.TrackID) == "" {
		return "", fmt.Errorf("no songs found on spotify")
	}
	return strings.TrimSpace(best.TrackID), nil
}

func selectBestSpotifyLyricsSearchResult(results []spotifyLyricsSearchResult, trackName, artistName string, durationSec float64) *spotifyLyricsSearchResult {
	if len(results) == 0 {
		return nil
	}
	bestIndex, bestScore := 0, -1
	for i := range results {
		result := &results[i]
		score := scoreLyricsSearchCandidate(result.Name, result.ArtistName, parseClockDuration(result.Duration), trackName, artistName, durationSec)
		if score > bestScore {
			bestIndex = i
			bestScore = score
		}
	}
	return &results[bestIndex]
}

func (c *SpotifyLyricsClient) fetchLyricsByID(trackID string) (*LyricsResponse, error) {
	params := url.Values{}
	params.Set("id", trackID)
	raw, err := fetchPaxsenixBody(c.httpClient, "https://lyrics.paxsenix.org/spotify/lyrics", params)
	if err != nil {
		return nil, fmt.Errorf("spotify lyrics fetch failed: %w", err)
	}
	return parsePaxsenixLyricsPayload(raw, "Spotify", false)
}

func (c *SpotifyLyricsClient) FetchLyrics(spotifyID, trackName, artistName string, durationSec float64) (*LyricsResponse, error) {
	trackID := normalizeSpotifyLyricsID(spotifyID)
	if trackID == "" {
		var err error
		trackID, err = c.searchSong(trackName, artistName, durationSec)
		if err != nil {
			return nil, err
		}
	}
	return c.fetchLyricsByID(trackID)
}
