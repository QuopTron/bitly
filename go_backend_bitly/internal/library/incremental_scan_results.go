package library

import (
	"encoding/json"
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

func filterChangedFiles(currentFiles []libraryAudioFileInfo, existingFiles map[string]int64, currentPathSet map[string]bool) (filesToScan []libraryAudioFileInfo, skippedCount int, deletedPaths []string) {
	for _, f := range currentFiles {
		existingModTime, exists := existingFiles[f.path]
		if exists && f.modTime == existingModTime {
			skippedCount++
		} else {
			filesToScan = append(filesToScan, f)
		}
	}

	for existingPath := range existingFiles {
		if !currentPathSet[existingPath] {
			if idx := strings.LastIndex(existingPath, "#track"); idx > 0 {
				baseCuePath := existingPath[:idx]
				if currentPathSet[baseCuePath] {
					continue
				}
			}
			deletedPaths = append(deletedPaths, existingPath)
		}
	}
	return
}

func buildEarlyScanResult(deletedPaths []string, skippedCount, totalFiles int) string {
	libraryScanProgressMu.Lock()
	libraryScanProgress.ScannedFiles = totalFiles
	libraryScanProgress.IsComplete = true
	libraryScanProgress.ProgressPct = 100
	libraryScanProgressMu.Unlock()

	result := IncrementalScanResult{
		Scanned:      []database.LibraryScanResult{},
		DeletedPaths: deletedPaths,
		SkippedCount: skippedCount,
		TotalFiles:   totalFiles,
	}
	jsonBytes, _ := json.Marshal(result)
	return string(jsonBytes)
}

func buildFinalScanResult(results []database.LibraryScanResult, deletedPaths []string, skippedCount, totalFiles, errorCount int) (string, error) {
	libraryScanProgressMu.Lock()
	libraryScanProgress.ErrorCount = errorCount
	libraryScanProgress.IsComplete = true
	libraryScanProgress.ScannedFiles = totalFiles
	libraryScanProgress.ProgressPct = 100
	libraryScanProgressMu.Unlock()

	scanResult := IncrementalScanResult{
		Scanned:      results,
		DeletedPaths: deletedPaths,
		SkippedCount: skippedCount,
		TotalFiles:   totalFiles,
	}
	jsonBytes, err := json.Marshal(scanResult)
	if err != nil {
		return "{}", nil
	}
	return string(jsonBytes), nil
}
