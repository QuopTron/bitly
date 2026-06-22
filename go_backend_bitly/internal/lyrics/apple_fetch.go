package lyrics

import (
	"fmt"
	"math"
	"strings"
)

func scoreLyricsSearchCandidate(candidateTrack, candidateArtist string, candidateDuration float64, trackName, artistName string, durationSec float64) int {
	normalizedTrack := strings.ToLower(strings.TrimSpace(SimplifyTrackName(trackName)))
	normalizedArtist := strings.ToLower(strings.TrimSpace(NormalizeArtistName(artistName)))
	candidateTrack = strings.ToLower(strings.TrimSpace(SimplifyTrackName(candidateTrack)))
	candidateArtist = strings.ToLower(strings.TrimSpace(NormalizeArtistName(candidateArtist)))

	score := 0
	switch {
	case candidateTrack == normalizedTrack:
		score += 50
	case strings.Contains(candidateTrack, normalizedTrack) || strings.Contains(normalizedTrack, candidateTrack):
		score += 25
	}
	switch {
	case candidateArtist == normalizedArtist:
		score += 60
	case strings.Contains(candidateArtist, normalizedArtist) || strings.Contains(normalizedArtist, candidateArtist):
		score += 30
	}
	if durationSec > 0 && candidateDuration > 0 {
		if math.Abs(candidateDuration-durationSec) <= durationToleranceSec {
			score += 20
		}
	}
	return score
}

func (c *AppleMusicClient) FetchLyrics(trackName, artistName string, durationSec float64, multiPersonWordByWord, appleElrcWordSync bool) (*LyricsResponse, error) {
	songID, err := c.SearchSong(trackName, artistName, durationSec)
	if err != nil {
		return nil, err
	}

	rawLyrics, err := c.FetchLyricsByID(songID)
	if err != nil {
		return nil, err
	}
	if errMsg, isErrorPayload := DetectLyricsErrorPayload(rawLyrics); isErrorPayload {
		return nil, fmt.Errorf("apple music proxy returned non-lyric payload: %s", errMsg)
	}

	lrcText, err := formatPaxLyricsToLRC(rawLyrics, multiPersonWordByWord, appleElrcWordSync)
	if err != nil {
		lrcText = rawLyrics
	}

	lines := ParseSyncedLyrics(lrcText)
	if len(lines) > 0 {
		return &LyricsResponse{Lines: lines, SyncType: "LINE_SYNCED", Provider: "Apple Music", Source: "Apple Music"}, nil
	}

	resultLines := PlainTextLyricsLines(lrcText)
	if len(resultLines) > 0 {
		return &LyricsResponse{Lines: resultLines, SyncType: "UNSYNCED", Provider: "Apple Music", Source: "Apple Music"}, nil
	}
	return nil, fmt.Errorf("no lyrics found on apple music")
}
