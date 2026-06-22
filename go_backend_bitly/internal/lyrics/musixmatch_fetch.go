package lyrics

import (
	"fmt"
	"strings"
)

func (c *MusixmatchClient) FetchLyricsInLanguage(trackName, artistName string, durationSec float64, language string) (*LyricsResponse, error) {
	lang := strings.ToLower(strings.TrimSpace(language))
	if lang == "" {
		return nil, fmt.Errorf("invalid language")
	}
	lrcText, err := c.fetchLyricsPayload(trackName, artistName, durationSec, "translate", lang)
	if err != nil {
		return nil, err
	}
	lines := ParseSyncedLyrics(lrcText)
	if len(lines) > 0 {
		return &LyricsResponse{
			Lines:       lines,
			SyncType:    "LINE_SYNCED",
			PlainLyrics: PlainLyricsFromTimedLines(lines),
			Provider:    "Musixmatch",
			Source:      fmt.Sprintf("Musixmatch (%s)", lang),
		}, nil
	}
	plainLines := PlainTextLyricsLines(lrcText)
	if len(plainLines) > 0 {
		return &LyricsResponse{
			Lines:       plainLines,
			SyncType:    "UNSYNCED",
			PlainLyrics: lrcText,
			Provider:    "Musixmatch",
			Source:      fmt.Sprintf("Musixmatch (%s)", lang),
		}, nil
	}
	return nil, fmt.Errorf("no lyrics found on musixmatch for language %s", lang)
}

func (c *MusixmatchClient) FetchLyrics(trackName, artistName string, durationSec float64, preferredLanguage string) (*LyricsResponse, error) {
	if preferred := strings.ToLower(strings.TrimSpace(preferredLanguage)); preferred != "" {
		if localized, err := c.FetchLyricsInLanguage(trackName, artistName, durationSec, preferred); err == nil {
			return localized, nil
		}
	}

	lrcText, err := c.fetchLyricsPayload(trackName, artistName, durationSec, "word", "")
	if err != nil {
		return nil, err
	}
	lines := ParseSyncedLyrics(lrcText)
	if len(lines) > 0 {
		return &LyricsResponse{
			Lines:       lines,
			SyncType:    "LINE_SYNCED",
			PlainLyrics: PlainLyricsFromTimedLines(lines),
			Provider:    "Musixmatch",
			Source:      "Musixmatch",
		}, nil
	}
	plainLines := PlainTextLyricsLines(lrcText)
	if len(plainLines) > 0 {
		return &LyricsResponse{
			Lines:       plainLines,
			SyncType:    "UNSYNCED",
			PlainLyrics: lrcText,
			Provider:    "Musixmatch",
			Source:      "Musixmatch",
		}, nil
	}
	return nil, fmt.Errorf("no lyrics found on musixmatch")
}
