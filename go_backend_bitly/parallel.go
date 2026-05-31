package gobackend

import (
	"fmt"
	"sync"
)

type PreWarmCacheRequest struct {
	ISRC       string
	TrackName  string
	ArtistName string
	SpotifyID  string
	Service    string
}

func PreWarmTrackCache(requests []PreWarmCacheRequest) {
	_ = requests
}

func GetCacheSize() int {
	return 0
}

func ClearTrackCache() {
}

type ParallelDownloadResult struct {
	CoverData  []byte
	LyricsData *LyricsResponse
	LyricsLRC  string
	CoverErr   error
	LyricsErr  error
}

func FetchCoverAndLyricsParallel(
	coverURL string,
	maxQualityCover bool,
	spotifyID string,
	trackName string,
	artistName string,
	embedLyrics bool,
	durationMs int64,
) *ParallelDownloadResult {
	result := &ParallelDownloadResult{}
	var wg sync.WaitGroup
	var resultMu sync.Mutex

	if coverURL != "" {
		wg.Add(1)
		go func() {
			defer wg.Done()
			data, err := downloadCoverToMemory(coverURL, maxQualityCover)
			resultMu.Lock()
			if err != nil {
				result.CoverErr = err
			} else {
				result.CoverData = data
			}
			resultMu.Unlock()
		}()
	}

	if embedLyrics {
		wg.Add(1)
		go func() {
			defer wg.Done()
			client := NewLyricsClient()
			durationSec := float64(durationMs) / 1000.0
			lyrics, err := client.FetchLyricsAllSources(spotifyID, trackName, artistName, durationSec)
			resultMu.Lock()
			if err != nil {
				result.LyricsErr = err
			} else if lyrics != nil && len(lyrics.Lines) > 0 {
				result.LyricsData = lyrics
				result.LyricsLRC = convertToLRCWithMetadata(lyrics, trackName, artistName)
			} else {
				result.LyricsErr = fmt.Errorf("no lyrics found")
			}
			resultMu.Unlock()
		}()
	}

	wg.Wait()
	return result
}
