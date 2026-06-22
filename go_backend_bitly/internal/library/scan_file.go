package library

import (
	"os"
	"path/filepath"
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/audio/metadata"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

func scanAudioFileWithKnownModTime(filePath, scanTime string, knownModTime int64) (*database.LibraryScanResult, error) {
	return scanAudioFileWithKnownModTimeAndDisplayNameAndCoverCacheKey(filePath, "", "", scanTime, knownModTime)
}

func scanAudioFileWithKnownModTimeAndDisplayNameAndCoverCacheKey(filePath, displayNameHint, coverCacheKey, scanTime string, knownModTime int64) (*database.LibraryScanResult, error) {
	ext := resolveLibraryAudioExt(filePath, displayNameHint)
	result := &database.LibraryScanResult{
		ID:        generateLibraryID(filePath),
		FilePath:  filePath,
		ScannedAt: scanTime,
		Format:    strings.TrimPrefix(ext, "."),
	}
	if knownModTime > 0 {
		result.FileModTime = knownModTime
	} else if info, err := os.Stat(filePath); err == nil {
		result.FileModTime = info.ModTime().UnixMilli()
	}

	libraryCoverCacheMu.RLock()
	coverCacheDir := libraryCoverCacheDir
	libraryCoverCacheMu.RUnlock()
	if coverCacheDir != "" {
		coverPath, err := metadata.SaveCoverToCacheWithHintAndKey(filePath, displayNameHint, coverCacheDir, coverCacheKey)
		if err == nil && coverPath != "" {
			result.CoverPath = coverPath
		}
	}

	switch ext {
	case ".flac":
		return scanFLACFile(filePath, result, displayNameHint)
	case ".m4a":
		return scanM4AFile(filePath, result, displayNameHint)
	case ".mp3":
		return scanMP3File(filePath, result, displayNameHint)
	case ".opus", ".ogg":
		return scanOggFile(filePath, result, displayNameHint)
	case ".ape", ".wv", ".mpc":
		return scanAPEFile(filePath, result, displayNameHint)
	default:
		return scanFromFilename(filePath, displayNameHint, result)
	}
}

func resolveLibraryAudioExt(filePath, displayNameHint string) string {
	ext := strings.ToLower(filepath.Ext(filePath))
	if ext != "" {
		return ext
	}
	return strings.ToLower(filepath.Ext(displayNameHint))
}

func libraryDisplayNameOrPath(filePath, displayNameHint string) string {
	if displayNameHint != "" {
		return displayNameHint
	}
	return filePath
}

func applyDefaultLibraryMetadata(filePath, displayNameHint string, result *database.LibraryScanResult) {
	nameSource := libraryDisplayNameOrPath(filePath, displayNameHint)
	if result.TrackName == "" {
		result.TrackName = strings.TrimSuffix(filepath.Base(nameSource), filepath.Ext(nameSource))
	}
	if result.ArtistName == "" {
		result.ArtistName = "Unknown Artist"
	}
	if result.AlbumName == "" {
		result.AlbumName = "Unknown Album"
	}
}

func applyQualityFields(result *database.LibraryScanResult, bitDepth, sampleRate, duration, bitrate int) {
	result.BitDepth = bitDepth
	result.SampleRate = sampleRate
	if duration > 0 {
		result.Duration = duration
	}
	if bitrate > 0 {
		result.Bitrate = bitrate
	}
}
