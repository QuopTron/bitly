package lyrics

import (
	"encoding/json"
	"fmt"
	"math"
	"net/http"
	"net/url"
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/http"
)

func (c *LyricsClient) FetchLyricsWithMetadata(artist, track string) (*LyricsResponse, error) {
	baseURL := "https://lrclib.net/api/get"
	params := url.Values{}
	params.Set("artist_name", artist)
	params.Set("track_name", track)

	req, err := http.NewRequest("GET", baseURL+"?"+params.Encode(), nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("User-Agent", httpclient.UserAgentForURL(nil))

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch lyrics: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode == 404 {
		return nil, fmt.Errorf("lyrics not found")
	}
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	var lrcResp LRCLibResponse
	if err := json.NewDecoder(resp.Body).Decode(&lrcResp); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}
	return c.parseLRCLibResponse(&lrcResp), nil
}

func (c *LyricsClient) FetchLyricsFromLRCLibSearch(query string, durationSec float64) (*LyricsResponse, error) {
	baseURL := "https://lrclib.net/api/search"
	params := url.Values{}
	params.Set("q", query)

	req, err := http.NewRequest("GET", baseURL+"?"+params.Encode(), nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("User-Agent", httpclient.UserAgentForURL(nil))

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("failed to search lyrics: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	var results []LRCLibResponse
	if err := json.NewDecoder(resp.Body).Decode(&results); err != nil {
		return nil, fmt.Errorf("failed to decode response: %w", err)
	}
	if len(results) == 0 {
		return nil, fmt.Errorf("no lyrics found")
	}

	bestMatch := c.findBestMatch(results, durationSec)
	if bestMatch != nil {
		return c.parseLRCLibResponse(bestMatch), nil
	}
	for _, result := range results {
		if result.SyncedLyrics != "" {
			return c.parseLRCLibResponse(&result), nil
		}
	}
	return c.parseLRCLibResponse(&results[0]), nil
}

const durationToleranceSec = 10.0

func (c *LyricsClient) findBestMatch(results []LRCLibResponse, targetDurationSec float64) *LRCLibResponse {
	var bestSynced, bestPlain *LRCLibResponse
	for i := range results {
		result := &results[i]
		durationMatches := targetDurationSec == 0 || c.durationMatches(result.Duration, targetDurationSec)
		if durationMatches {
			if result.SyncedLyrics != "" && bestSynced == nil {
				bestSynced = result
			} else if result.PlainLyrics != "" && bestPlain == nil {
				bestPlain = result
			}
		}
	}
	if bestSynced != nil {
		return bestSynced
	}
	return bestPlain
}

func (c *LyricsClient) durationMatches(lrcDuration, targetDuration float64) bool {
	return math.Abs(lrcDuration-targetDuration) <= durationToleranceSec
}

func (c *LyricsClient) parseLRCLibResponse(resp *LRCLibResponse) *LyricsResponse {
	result := &LyricsResponse{
		Instrumental: resp.Instrumental,
		PlainLyrics:  resp.PlainLyrics,
		Provider:     "LRCLIB",
	}
	if resp.SyncedLyrics != "" {
		result.Lines = ParseSyncedLyrics(resp.SyncedLyrics)
		result.SyncType = "LINE_SYNCED"
	} else if resp.PlainLyrics != "" {
		result.SyncType = "UNSYNCED"
		for _, line := range strings.Split(resp.PlainLyrics, "\n") {
			if strings.TrimSpace(line) != "" {
				result.Lines = append(result.Lines, LyricsLine{
					StartTimeMs: 0,
					Words:       line,
					EndTimeMs:   0,
				})
			}
		}
	}
	return result
}
