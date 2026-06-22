package lyrics

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"

	httpclient "github.com/zarz/bitly/go_backend_bitly/internal/http"
)

func (c *NeteaseClient) FetchLyricsByID(songID int64, includeTranslation, includeRomanization bool) (string, error) {
	params := url.Values{}
	params.Set("id", fmt.Sprintf("%d", songID))
	lyricsURL := "https://lyrics.paxsenix.org/netease/lyrics?" + params.Encode()

	req, err := http.NewRequest("GET", lyricsURL, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create request: %w", err)
	}
	req.Header.Set("Accept", "application/json")
	req.Header.Set("Accept-Language", "en-US,en;q=0.9")
	req.Header.Set("User-Agent", httpclient.UserAgentForURL(nil))

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("netease lyrics fetch failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		return "", fmt.Errorf("netease lyrics returned HTTP %d", resp.StatusCode)
	}

	var lyricsResp neteaseLyricsResponse
	if err := json.NewDecoder(resp.Body).Decode(&lyricsResp); err != nil {
		return "", fmt.Errorf("failed to decode netease lyrics: %w", err)
	}

	if lyricsResp.LRC == nil || strings.TrimSpace(lyricsResp.LRC.Lyric) == "" {
		return "", fmt.Errorf("no lyrics available on netease")
	}

	lyric := lyricsResp.LRC.Lyric
	if includeTranslation && lyricsResp.TLyric != nil && strings.TrimSpace(lyricsResp.TLyric.Lyric) != "" {
		lyric += "\n\n" + lyricsResp.TLyric.Lyric
	}
	if includeRomanization && lyricsResp.RomaLRC != nil && strings.TrimSpace(lyricsResp.RomaLRC.Lyric) != "" {
		lyric += "\n\n" + lyricsResp.RomaLRC.Lyric
	}
	return lyric, nil
}

func (c *NeteaseClient) FetchLyrics(trackName, artistName string, durationSec float64, includeTranslation, includeRomanization bool) (*LyricsResponse, error) {
	songID, err := c.SearchSong(trackName, artistName)
	if err != nil {
		return nil, err
	}

	lrcText, err := c.FetchLyricsByID(songID, includeTranslation, includeRomanization)
	if err != nil {
		return nil, err
	}

	lines := ParseSyncedLyrics(lrcText)
	if len(lines) == 0 {
		plainLines := PlainTextLyricsLines(lrcText)
		if len(plainLines) > 0 {
			return &LyricsResponse{Lines: plainLines, SyncType: "UNSYNCED", Provider: "Netease", Source: "Netease"}, nil
		}
		return nil, fmt.Errorf("netease returned empty lyrics")
	}
	return &LyricsResponse{Lines: lines, SyncType: "LINE_SYNCED", Provider: "Netease", Source: "Netease"}, nil
}
