package utils

import (
	"fmt"
	"os"
	"path/filepath"
)

func TruncateUTF8Bytes(value string, maxBytes int) string {
	if maxBytes <= 0 || len(value) <= maxBytes {
		return value
	}
	used := 0
	for i, r := range value {
		runeLen := len(string(r))
		if used+runeLen > maxBytes {
			return value[:i]
		}
		used += runeLen
	}
	return value
}

func ResolveOutputPathForDownload(outputDir, baseFilename, extension string, useSuffix bool) string {
	ext := extension
	if ext == "" {
		ext = ".flac"
	}
	if ext[0] != '.' {
		ext = "." + ext
	}
	base := filepath.Join(outputDir, SanitizeFilename(baseFilename))
	candidate := base + ext

	if !useSuffix {
		return candidate
	}

	for i := 1; i <= 99; i++ {
		if _, err := os.Stat(candidate); os.IsNotExist(err) {
			return candidate
		}
		candidate = fmt.Sprintf("%s_%02d%s", base, i, ext)
	}
	return candidate
}

func FileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func MustFileSize(path string) int64 {
	info, err := os.Stat(path)
	if err != nil {
		return 0
	}
	return info.Size()
}
