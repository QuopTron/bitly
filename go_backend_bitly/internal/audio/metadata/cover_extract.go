package metadata

import (
	"fmt"
	"os"
	"strings"
)

// ExtractAnyCoverArt extracts cover art from any supported audio format.
func ExtractAnyCoverArt(filePath string) ([]byte, string, error) {
	return ExtractAnyCoverArtWithHint(filePath, "")
}

// ExtractAnyCoverArtWithHint extracts cover art with a display name hint.
func ExtractAnyCoverArtWithHint(filePath, displayNameHint string) ([]byte, string, error) {
	ext := strings.ToLower(filepathExt(filePath))
	if ext == "" {
		ext = strings.ToLower(filepathExt(displayNameHint))
	}

	switch ext {
	case ".flac":
		data, err := ExtractCoverArt(filePath)
		if err != nil {
			return nil, "", err
		}
		mimeType := "image/jpeg"
		if len(data) > 8 && string(data[1:4]) == "PNG" {
			mimeType = "image/png"
		}
		return data, mimeType, nil
	case ".mp3":
		return ExtractMP3CoverArt(filePath)
	case ".opus", ".ogg":
		return ExtractOggCoverArt(filePath)
	case ".m4a":
		data, err := ExtractCoverFromM4A(filePath)
		if err != nil {
			return nil, "", err
		}
		mimeType := "image/jpeg"
		if len(data) >= 8 && data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 {
			mimeType = "image/png"
		}
		return data, mimeType, nil
	default:
		return nil, "", fmt.Errorf("unsupported format: %s", ext)
	}
}

func filepathExt(path string) string {
	for i := len(path) - 1; i >= 0; i-- {
		if path[i] == '.' {
			return path[i:]
		}
		if path[i] == '/' || path[i] == '\\' {
			break
		}
	}
	return ""
}

// SaveCoverToCache extracts cover art and caches it to disk.
func SaveCoverToCache(filePath, cacheDir string) (string, error) {
	return SaveCoverToCacheWithHintAndKey(filePath, "", cacheDir, "")
}

// SaveCoverToCacheWithHint saves cover with a display name hint.
func SaveCoverToCacheWithHint(filePath, displayNameHint, cacheDir string) (string, error) {
	return SaveCoverToCacheWithHintAndKey(filePath, displayNameHint, cacheDir, "")
}

// SaveCoverToCacheWithHintAndKey saves cover with a custom cache key.
func SaveCoverToCacheWithHintAndKey(filePath, displayNameHint, cacheDir, coverCacheKey string) (string, error) {
	cacheKey := coverCacheKey
	if cacheKey == "" {
		cacheKey = filePath
		if stat, err := os.Stat(filePath); err == nil {
			cacheKey = fmt.Sprintf("%s|%d|%d", filePath, stat.Size(), stat.ModTime().UnixNano())
		}
	}

	hash := fnvHash(cacheKey)
	jpgPath := cacheDir + "/cover_" + fmt.Sprintf("%x", hash) + ".jpg"
	pngPath := cacheDir + "/cover_" + fmt.Sprintf("%x", hash) + ".png"

	if _, err := os.Stat(jpgPath); err == nil {
		return jpgPath, nil
	}
	if _, err := os.Stat(pngPath); err == nil {
		return pngPath, nil
	}

	imageData, mimeType, err := ExtractAnyCoverArtWithHint(filePath, displayNameHint)
	if err != nil {
		return "", err
	}

	if err := os.MkdirAll(cacheDir, 0755); err != nil {
		return "", fmt.Errorf("failed to create cache dir: %w", err)
	}

	var cachePath string
	if strings.Contains(mimeType, "png") {
		cachePath = pngPath
	} else {
		cachePath = jpgPath
	}
	if err := os.WriteFile(cachePath, imageData, 0644); err != nil {
		return "", fmt.Errorf("failed to write cover: %w", err)
	}
	return cachePath, nil
}

func fnvHash(s string) uint64 {
	var h uint64 = 14695981039346656037
	for i := 0; i < len(s); i++ {
		h ^= uint64(s[i])
		h *= 1099511628211
	}
	return h
}
