package metadata

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// ExtractCoverFromFile extracts cover art from any supported audio format.
func ExtractCoverFromFile(filePath string) ([]byte, string, error) {
	return ExtractAnyCoverArt(filePath)
}

// CacheCoverToFile extracts and caches cover art to a local file.
func CacheCoverToFile(filePath, cacheDir string) (string, error) {
	return SaveCoverToCache(filePath, cacheDir)
}

// ExtractLyricsFromFile extracts lyrics from any supported audio format.
func ExtractLyricsFromFile(filePath string) (string, error) {
	return ExtractLyrics(filePath)
}

// FileExists checks if a file exists on disk.
func FileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

// FilePathExt returns the file extension (including the dot).
func FilePathExt(path string) string {
	return filepath.Ext(path)
}

// DeleteFileAndCleanupFolder deletes a file and removes its parent folder if empty.
func DeleteFileAndCleanupFolder(filePath string) error {
	if err := os.Remove(filePath); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("failed to delete file: %w", err)
	}
	parent := filepath.Dir(filePath)
	entries, err := os.ReadDir(parent)
	if err != nil {
		return nil
	}
	if len(entries) == 0 {
		os.Remove(parent)
	}
	return nil
}

// DeleteSidecarFiles deletes .lrc and .jpg sidecar files for an audio file.
func DeleteSidecarFiles(audioPath string) error {
	ext := filepath.Ext(audioPath)
	base := strings.TrimSuffix(audioPath, ext)
	for _, sidecar := range []string{".lrc", ".jpg", ".png"} {
		path := base + sidecar
		if err := os.Remove(path); err != nil && !os.IsNotExist(err) {
			return fmt.Errorf("failed to delete sidecar %s: %w", path, err)
		}
	}
	return nil
}
