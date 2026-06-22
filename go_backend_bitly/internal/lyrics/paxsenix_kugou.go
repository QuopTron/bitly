package lyrics

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/http"
)

type KugouLyricsClient struct {
	httpClient *http.Client
}

type kugouLyricsSearchResult struct {
	Hash     string  `json:"hash"`
	Title    string  `json:"title"`
	Artist   string  `json:"artist"`
	Duration float64 `json:"duration"`
}

func NewKugouLyricsClient() *KugouLyricsClient {
	return &KugouLyricsClient{httpClient: httpclient.NewMetadataClient(15 * time.Second)}
}

func (c *KugouLyricsClient) searchSong(trackName, artistName string, durationSec float64) (string, error) {
	query := strings.TrimSpace(trackName + " " + artistName)
	if query == "" {
		return "", fmt.Errorf("empty search query")
	}
	params := url.Values{}
	params.Set("q", query)
	raw, err := fetchPaxsenixBody(c.httpClient, "https://lyrics.paxsenix.org/kugou/search", params)
	if err != nil {
		return "", fmt.Errorf("kugou search failed: %w", err)
	}

	var results []kugouLyricsSearchResult
	if err := json.Unmarshal([]byte(raw), &results); err != nil {
		return "", fmt.Errorf("failed to decode kugou search: %w", err)
	}
	best := selectBestKugouLyricsSearchResult(results, trackName, artistName, durationSec)
	if best == nil || strings.TrimSpace(best.Hash) == "" {
		return "", fmt.Errorf("no songs found on kugou")
	}
	return strings.TrimSpace(best.Hash), nil
}

func selectBestKugouLyricsSearchResult(results []kugouLyricsSearchResult, trackName, artistName string, durationSec float64) *kugouLyricsSearchResult {
	if len(results) == 0 {
		return nil
	}
	bestIndex, bestScore := 0, -1
	for i := range results {
		result := &results[i]
		score := scoreLyricsSearchCandidate(result.Title, result.Artist, result.Duration, trackName, artistName, durationSec)
		if score > bestScore {
			bestIndex = i
			bestScore = score
		}
	}
	return &results[bestIndex]
}

func (c *KugouLyricsClient) FetchLyrics(trackName, artistName string, durationSec float64) (*LyricsResponse, error) {
	hash, err := c.searchSong(trackName, artistName, durationSec)
	if err != nil {
		return nil, err
	}
	params := url.Values{}
	params.Set("id", hash)
	raw, err := fetchPaxsenixBody(c.httpClient, "https://lyrics.paxsenix.org/kugou/lyrics", params)
	if err != nil {
		return nil, fmt.Errorf("kugou lyrics fetch failed: %w", err)
	}
	return parsePaxsenixLyricsPayload(raw, "Kugou", false)
}
