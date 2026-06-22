package core

import (
	"encoding/json"
	"fmt"
	"os"
	"sync"
)

func CheckFileExists(filePath string) bool {
	info, err := os.Stat(filePath)
	if err != nil {
		return false
	}
	return !info.IsDir() && info.Size() > 0
}

func CheckISRCExists(outputDir, isrc string) (string, error) {
	if isrc == "" || outputDir == "" {
		return "", nil
	}
	idx := GetISRCIndex(outputDir)
	filePath, exists := idx.lookup(isrc)
	if !exists {
		return "", nil
	}
	if !CheckFileExists(filePath) {
		idx.remove(isrc)
		return "", nil
	}
	return filePath, nil
}

type FileExistenceResult struct {
	ISRC       string `json:"isrc"`
	Exists     bool   `json:"exists"`
	FilePath   string `json:"file_path,omitempty"`
	TrackName  string `json:"track_name,omitempty"`
	ArtistName string `json:"artist_name,omitempty"`
}

func CheckFilesExistParallel(outputDir string, tracksJSON string) (string, error) {
	var tracks []struct {
		ISRC       string `json:"isrc"`
		TrackName  string `json:"track_name"`
		ArtistName string `json:"artist_name"`
	}
	if err := json.Unmarshal([]byte(tracksJSON), &tracks); err != nil {
		return "", fmt.Errorf("failed to parse tracks JSON: %w", err)
	}

	results := make([]FileExistenceResult, len(tracks))
	isrcIdx := GetISRCIndex(outputDir)

	var wg sync.WaitGroup
	for i, track := range tracks {
		wg.Add(1)
		go func(resultIdx int, t struct {
			ISRC       string `json:"isrc"`
			TrackName  string `json:"track_name"`
			ArtistName string `json:"artist_name"`
		}) {
			defer wg.Done()
			result := FileExistenceResult{
				ISRC:       t.ISRC,
				TrackName:  t.TrackName,
				ArtistName: t.ArtistName,
				Exists:     false,
			}
			if t.ISRC != "" {
				if filePath, exists := isrcIdx.lookup(t.ISRC); exists {
					result.Exists = true
					result.FilePath = filePath
				}
			}
			results[resultIdx] = result
		}(i, track)
	}
	wg.Wait()

	resultJSON, err := json.Marshal(results)
	if err != nil {
		return "", fmt.Errorf("failed to marshal results: %w", err)
	}
	return string(resultJSON), nil
}

func PreBuildISRCIndex(outputDir string) error {
	if outputDir == "" {
		return fmt.Errorf("output directory is required")
	}
	buildISRCIndex(outputDir)
	return nil
}

func AddToISRCIndex(outputDir, isrc, filePath string) {
	if outputDir == "" || isrc == "" || filePath == "" {
		return
	}
	isrcIndexCacheMu.RLock()
	idx, exists := isrcIndexCache[outputDir]
	isrcIndexCacheMu.RUnlock()
	if exists {
		idx.Add(isrc, filePath)
	}
}
