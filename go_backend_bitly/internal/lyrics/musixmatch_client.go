package lyrics

import (
	"encoding/json"
	"fmt"
	"io"
	"math"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/http"
)

type MusixmatchClient struct {
	httpClient *http.Client
	baseURL    string
}

func NewMusixmatchClient() *MusixmatchClient {
	return &MusixmatchClient{
		httpClient: httpclient.NewMetadataClient(15 * time.Second),
		baseURL:    "https://lyrics.paxsenix.org/musixmatch/lyrics",
	}
}

func (c *MusixmatchClient) fetchLyricsPayload(trackName, artistName string, durationSec float64, lyricsType, language string) (string, error) {
	if strings.TrimSpace(trackName) == "" || strings.TrimSpace(artistName) == "" {
		return "", fmt.Errorf("empty track or artist name")
	}

	params := url.Values{}
	params.Set("t", trackName)
	params.Set("a", artistName)
	params.Set("type", lyricsType)
	params.Set("format", "lrc")
	if durationSec > 0 {
		params.Set("d", fmt.Sprintf("%d", int(math.Round(durationSec))))
	}
	if strings.TrimSpace(language) != "" {
		params.Set("l", strings.ToLower(strings.TrimSpace(language)))
	}

	fullURL := c.baseURL + "?" + params.Encode()
	req, err := http.NewRequest("GET", fullURL, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", httpclient.UserAgentForURL(nil))

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("musixmatch request failed: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read musixmatch response: %w", err)
	}

	if resp.StatusCode != 200 {
		trimmed := strings.TrimSpace(string(body))
		if errMsg, isErrorPayload := DetectLyricsErrorPayload(trimmed); isErrorPayload {
			return "", fmt.Errorf("musixmatch proxy returned HTTP %d: %s", resp.StatusCode, errMsg)
		}
		return "", fmt.Errorf("musixmatch proxy returned HTTP %d", resp.StatusCode)
	}

	var lrcPayload string
	if err := json.Unmarshal(body, &lrcPayload); err == nil {
		lrcPayload = strings.TrimSpace(lrcPayload)
		if lrcPayload == "" {
			return "", fmt.Errorf("empty musixmatch lyrics payload")
		}
		return lrcPayload, nil
	}

	trimmed := strings.TrimSpace(string(body))
	if errMsg, isErrorPayload := DetectLyricsErrorPayload(trimmed); isErrorPayload {
		return "", fmt.Errorf("%s", errMsg)
	}
	if trimmed != "" && !strings.HasPrefix(trimmed, "{") {
		return trimmed, nil
	}
	return "", fmt.Errorf("failed to decode musixmatch response")
}
