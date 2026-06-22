package library

import (
	"fmt"
	"path/filepath"
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

func scanFromFilename(filePath, displayNameHint string, result *database.LibraryScanResult) (*database.LibraryScanResult, error) {
	nameSource := libraryDisplayNameOrPath(filePath, displayNameHint)
	filename := strings.TrimSuffix(filepath.Base(nameSource), filepath.Ext(nameSource))

	parts := strings.SplitN(filename, " - ", 2)
	if len(parts) == 2 {
		if len(parts[0]) <= 3 && isNumeric(parts[0]) {
			result.TrackName = parts[1]
			result.ArtistName = "Unknown Artist"
		} else {
			result.ArtistName = parts[0]
			result.TrackName = parts[1]
		}
	} else {
		if len(filename) > 3 && isNumeric(filename[:2]) {
			title := strings.TrimLeft(filename[2:], " .-")
			result.TrackName = title
		} else {
			result.TrackName = filename
		}
		result.ArtistName = "Unknown Artist"
	}

	dir := filepath.Dir(filePath)
	result.AlbumName = filepath.Base(dir)
	if result.AlbumName == "." || result.AlbumName == "" || result.AlbumName == "fd" || result.AlbumName == "self" {
		result.AlbumName = "Unknown Album"
	}

	return result, nil
}

func isNumeric(s string) bool {
	for _, c := range s {
		if c < '0' || c > '9' {
			return false
		}
	}
	return len(s) > 0
}

func generateLibraryID(filePath string) string {
	return fmt.Sprintf("lib_%x", hashString(filePath))
}

func hashString(s string) uint32 {
	var hash uint32 = 5381
	for _, c := range s {
		hash = ((hash << 5) + hash) + uint32(c)
	}
	return hash
}
