package lyrics

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/http"
)

type AppleMusicClient struct {
	httpClient *http.Client
}

type appleMusicSearchResult struct {
	ID         string `json:"id"`
	SongName   string `json:"songName"`
	ArtistName string `json:"artistName"`
	AlbumName  string `json:"albumName"`
	Duration   int    `json:"duration"`
}

func NewAppleMusicClient() *AppleMusicClient {
	return &AppleMusicClient{
		httpClient: httpclient.NewMetadataClient(20 * time.Second),
	}
}

func selectBestAppleMusicSearchResult(results []appleMusicSearchResult, trackName, artistName string, durationSec float64) *appleMusicSearchResult {
	if len(results) == 0 {
		return nil
	}
	normalizedArtist := strings.ToLower(strings.TrimSpace(NormalizeArtistName(artistName)))
	if normalizedArtist == "" {
		_ = strings.ToLower(strings.TrimSpace(artistName))
	}

	bestIndex, bestScore := 0, -1
	for i := range results {
		result := &results[i]
		score := scoreLyricsSearchCandidate(result.SongName, result.ArtistName, float64(result.Duration)/1000.0, trackName, artistName, durationSec)
		if score > bestScore {
			bestScore = score
			bestIndex = i
		}
	}
	return &results[bestIndex]
}

func (c *AppleMusicClient) SearchSong(trackName, artistName string, durationSec float64) (string, error) {
	query := strings.TrimSpace(trackName + " " + artistName)
	if query == "" {
		return "", fmt.Errorf("empty search query")
	}

	searchURL := "https://lyrics.paxsenix.org/apple-music/search?q=" + url.QueryEscape(query)
	req, err := http.NewRequest("GET", searchURL, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("User-Agent", httpclient.UserAgentForURL(nil))
	req.Header.Set("Accept", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("apple music search failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return "", fmt.Errorf("apple music search returned HTTP %d", resp.StatusCode)
	}

	var searchResp []appleMusicSearchResult
	if err := json.NewDecoder(resp.Body).Decode(&searchResp); err != nil {
		return "", fmt.Errorf("failed to decode apple music response: %w", err)
	}

	best := selectBestAppleMusicSearchResult(searchResp, trackName, artistName, durationSec)
	if best == nil || strings.TrimSpace(best.ID) == "" {
		return "", fmt.Errorf("no songs found on apple music")
	}
	return strings.TrimSpace(best.ID), nil
}

func (c *AppleMusicClient) FetchLyricsByID(songID string) (string, error) {
	lyricsURL := "https://lyrics.paxsenix.org/apple-music/lyrics?id=" + songID
	req, err := http.NewRequest("GET", lyricsURL, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("User-Agent", httpclient.UserAgentForURL(nil))
	req.Header.Set("Accept", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("apple music lyrics fetch failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return "", fmt.Errorf("apple music lyrics proxy returned HTTP %d", resp.StatusCode)
	}

	bodyBytes, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read lyrics response: %w", err)
	}
	bodyStr := strings.TrimSpace(string(bodyBytes))
	if bodyStr == "" {
		return "", fmt.Errorf("empty lyrics response from apple music")
	}
	return bodyStr, nil
}
