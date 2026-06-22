package library

import (
	"encoding/json"
	"fmt"
	"os"
	"strconv"
	"strings"
)

func loadExistingFilesSnapshot(snapshotPath string) (map[string]int64, error) {
	existingFiles := make(map[string]int64)
	if snapshotPath == "" {
		return existingFiles, nil
	}
	data, err := os.ReadFile(snapshotPath)
	if err != nil {
		return nil, err
	}
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		parts := strings.SplitN(line, "\t", 2)
		if len(parts) != 2 {
			continue
		}
		modTime, err := strconv.ParseInt(strings.TrimSpace(parts[0]), 10, 64)
		if err != nil {
			continue
		}
		existingFiles[strings.TrimSpace(parts[1])] = modTime
	}
	return existingFiles, nil
}

func ScanLibraryFolderIncremental(folderPath, existingFilesJSON string) (string, error) {
	existingFiles := make(map[string]int64)
	if existingFilesJSON != "" && existingFilesJSON != "{}" {
		if err := json.Unmarshal([]byte(existingFilesJSON), &existingFiles); err != nil {
			_ = err
		}
	}
	return scanLibraryFolderIncrementalWithExistingFiles(folderPath, existingFiles)
}

func ScanLibraryFolderIncrementalFromSnapshot(folderPath, snapshotPath string) (string, error) {
	existingFiles, err := loadExistingFilesSnapshot(snapshotPath)
	if err != nil {
		return "{}", fmt.Errorf("failed to load incremental snapshot: %w", err)
	}
	return scanLibraryFolderIncrementalWithExistingFiles(folderPath, existingFiles)
}
