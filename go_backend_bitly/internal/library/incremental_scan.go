package library

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

func scanLibraryFolderIncrementalWithExistingFiles(folderPath string, existingFiles map[string]int64) (string, error) {
	if folderPath == "" {
		return "{}", fmt.Errorf("folder path is empty")
	}
	info, err := os.Stat(folderPath)
	if err != nil {
		return "{}", fmt.Errorf("folder not found: %w", err)
	}
	if !info.IsDir() {
		return "{}", fmt.Errorf("path is not a folder: %s", folderPath)
	}

	libraryScanProgressMu.Lock()
	libraryScanProgress = LibraryScanProgress{}
	libraryScanProgressMu.Unlock()

	libraryScanCancelMu.Lock()
	if libraryScanCancel != nil {
		close(libraryScanCancel)
	}
	libraryScanCancel = make(chan struct{})
	cancelCh := libraryScanCancel
	libraryScanCancelMu.Unlock()

	currentFiles, err := collectLibraryAudioFiles(folderPath, cancelCh)
	if err != nil {
		return "{}", err
	}

	currentPathSet := make(map[string]bool, len(currentFiles))
	for _, f := range currentFiles {
		currentPathSet[f.path] = true
	}

	totalFiles := len(currentFiles)
	libraryScanProgressMu.Lock()
	libraryScanProgress.TotalFiles = totalFiles
	libraryScanProgressMu.Unlock()

	filesToScan, skippedCount, deletedPaths := filterChangedFiles(currentFiles, existingFiles, currentPathSet)

	if len(filesToScan) == 0 {
		return buildEarlyScanResult(deletedPaths, skippedCount, totalFiles), nil
	}

	results := make([]database.LibraryScanResult, 0, len(filesToScan))
	scanTime := time.Now().UTC().Format(time.RFC3339)
	errorCount := 0

	_ = scanCueFiles(filesToScan)

	for i, f := range filesToScan {
		select {
		case <-cancelCh:
			return "{}", fmt.Errorf("scan cancelled")
		default:
		}

		libraryScanProgressMu.Lock()
		libraryScanProgress.ScannedFiles = skippedCount + i + 1
		libraryScanProgress.CurrentFile = filepath.Base(f.path)
		libraryScanProgress.ProgressPct = float64(skippedCount+i+1) / float64(totalFiles) * 100
		libraryScanProgressMu.Unlock()

		ext := strings.ToLower(filepath.Ext(f.path))
		if ext == ".cue" {
			continue
		}

		result, err := scanAudioFileWithKnownModTime(f.path, scanTime, f.modTime)
		if err != nil {
			errorCount++
			continue
		}
		results = append(results, *result)
	}

	return buildFinalScanResult(results, deletedPaths, skippedCount, totalFiles, errorCount)
}
