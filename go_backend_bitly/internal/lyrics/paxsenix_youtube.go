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

type YouTubeLyricsClient struct {
	httpClient *http.Client
}

type youtubeLyricsSearchResult struct {
	VideoID  string `json:"videoId"`
	Title    string `json:"title"`
	Author   string `json:"author"`
	Duration string `json:"duration"`
}

func NewYouTubeLyricsClient() *YouTubeLyricsClient {
	return &YouTubeLyricsClient{httpClient: httpclient.NewMetadataClient(15 * time.Second)}
}

func (c *YouTubeLyricsClient) searchSong(trackName, artistName string, durationSec float64) (string, error) {
	query := strings.TrimSpace(trackName + " " + artistName)
	if query == "" {
		return "", fmt.Errorf("empty search query")
	}
	params := url.Values{}
	params.Set("q", query)
	raw, err := fetchPaxsenixBody(c.httpClient, "https://lyrics.paxsenix.org/youtube/search", params)
	if err != nil {
		return "", fmt.Errorf("youtube search failed: %w", err)
	}

	var results []youtubeLyricsSearchResult
	if err := json.Unmarshal([]byte(raw), &results); err != nil {
		return "", fmt.Errorf("failed to decode youtube search: %w", err)
	}
	best := selectBestYouTubeLyricsSearchResult(results, trackName, artistName, durationSec)
	if best == nil || strings.TrimSpace(best.VideoID) == "" {
		return "", fmt.Errorf("no songs found on youtube")
	}
	return strings.TrimSpace(best.VideoID), nil
}

func selectBestYouTubeLyricsSearchResult(results []youtubeLyricsSearchResult, trackName, artistName string, durationSec float64) *youtubeLyricsSearchResult {
	if len(results) == 0 {
		return nil
	}
	bestIndex, bestScore := 0, -1
	for i := range results {
		result := &results[i]
		score := scoreLyricsSearchCandidate(result.Title, result.Author, parseClockDuration(result.Duration), trackName, artistName, durationSec)
		if score > bestScore {
			bestIndex = i
			bestScore = score
		}
	}
	return &results[bestIndex]
}

func (c *YouTubeLyricsClient) FetchLyrics(trackName, artistName string, durationSec float64) (*LyricsResponse, error) {
	videoID, err := c.searchSong(trackName, artistName, durationSec)
	if err != nil {
		return nil, err
	}
	params := url.Values{}
	params.Set("id", videoID)
	raw, err := fetchPaxsenixBody(c.httpClient, "https://lyrics.paxsenix.org/youtube/lyrics", params)
	if err != nil {
		return nil, fmt.Errorf("youtube lyrics fetch failed: %w", err)
	}
	return parsePaxsenixLyricsPayload(raw, "YouTube", false)
}
