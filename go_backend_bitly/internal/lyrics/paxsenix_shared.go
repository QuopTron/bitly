package lyrics

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"

	httpclient "github.com/zarz/bitly/go_backend_bitly/internal/http"
)

type paxsenixLyricsObject struct {
	Type        string      `json:"type"`
	Content     []paxLyrics `json:"content"`
	Lyrics      []paxLyrics `json:"lyrics"`
	LyricsText  string      `json:"lyrics_text"`
	PlainLyrics string      `json:"plain_lyrics"`
}

func fetchPaxsenixBody(httpClient *http.Client, endpoint string, params url.Values) (string, error) {
	fullURL := endpoint
	if len(params) > 0 {
		fullURL += "?" + params.Encode()
	}
	req, err := http.NewRequest("GET", fullURL, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", httpclient.UserAgentForURL(nil))

	resp, err := httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("failed to read response: %w", err)
	}

	trimmed := strings.TrimSpace(string(body))
	if resp.StatusCode != http.StatusOK {
		if errMsg, isErrorPayload := DetectLyricsErrorPayload(trimmed); isErrorPayload {
			return "", fmt.Errorf("HTTP %d: %s", resp.StatusCode, errMsg)
		}
		return "", fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	if errMsg, isErrorPayload := DetectLyricsErrorPayload(trimmed); isErrorPayload {
		return "", fmt.Errorf("%s", errMsg)
	}
	if trimmed == "" {
		return "", fmt.Errorf("empty response")
	}
	return trimmed, nil
}

func parsePaxsenixLyricsPayload(raw, provider string, multiPersonWordByWord bool) (*LyricsResponse, error) {
	var lrcPayload string
	if err := json.Unmarshal([]byte(raw), &lrcPayload); err == nil {
		lrcPayload = strings.TrimSpace(lrcPayload)
		if lrcPayload == "" {
			return nil, fmt.Errorf("%s returned empty lyrics", provider)
		}
		return lyricsResponseFromText(lrcPayload, provider), nil
	}

	var rawObject map[string]json.RawMessage
	if err := json.Unmarshal([]byte(raw), &rawObject); err == nil {
		for _, key := range []string{"lyrics", "lyric", "lyrics_text", "plain_lyrics"} {
			var value string
			if rawValue, ok := rawObject[key]; ok && json.Unmarshal(rawValue, &value) == nil {
				value = strings.TrimSpace(value)
				if value != "" {
					return lyricsResponseFromText(value, provider), nil
				}
			}
		}
	}

	var payload paxsenixLyricsObject
	if err := json.Unmarshal([]byte(raw), &payload); err == nil {
		switch {
		case strings.TrimSpace(payload.LyricsText) != "":
			return lyricsResponseFromText(payload.LyricsText, provider), nil
		case len(payload.Lyrics) > 0:
			return lyricsResponseFromText(formatPaxContent("Syllable", payload.Lyrics, multiPersonWordByWord, false), provider), nil
		case len(payload.Content) > 0:
			lyricsType := payload.Type
			if lyricsType == "" {
				lyricsType = "Syllable"
			}
			return lyricsResponseFromText(formatPaxContent(lyricsType, payload.Content, multiPersonWordByWord, false), provider), nil
		case strings.TrimSpace(payload.PlainLyrics) != "":
			return lyricsResponseFromText(payload.PlainLyrics, provider), nil
		}
	}

	trimmed := strings.TrimSpace(raw)
	if trimmed != "" && !strings.HasPrefix(trimmed, "{") && !strings.HasPrefix(trimmed, "[") {
		return lyricsResponseFromText(trimmed, provider), nil
	}
	return nil, fmt.Errorf("failed to decode %s lyrics response", provider)
}


