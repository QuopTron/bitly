package cover

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/zarz/bitly/go_backend_bitly/internal/utils"
)

func detectMimeByMagic(data []byte) string {
	if len(data) < 4 {
		return "image/jpeg"
	}
	switch {
	case data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47:
		return "image/png"
	case data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF:
		return "image/jpeg"
	case data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46:
		return "image/gif"
	case len(data) >= 12 && string(data[:4]) == "RIFF" && string(data[8:12]) == "WEBP":
		return "image/webp"
	default:
		return "image/jpeg"
	}
}

func mimeExt(mime string) string {
	switch mime {
	case "image/png":
		return ".png"
	case "image/gif":
		return ".gif"
	case "image/webp":
		return ".webp"
	default:
		return ".jpg"
	}
}

func ResolveCoverPath(cacheDir, trackID, artistName, trackName string) string {
	if trackID != "" {
		hash := utils.HashString(trackID)
		for _, ext := range []string{".jpg", ".png", ".webp", ".gif"} {
			p := filepath.Join(cacheDir, fmt.Sprintf("cover_%x%s", hash, ext))
			if info, err := os.Stat(p); err == nil && info.Size() > 0 {
				return p
			}
		}
	}
	if artistName != "" && trackName != "" {
		safeArtist := utils.SanitizeFilename(artistName)
		safeTrack := utils.SanitizeFilename(trackName)
		base := fmt.Sprintf("%s - %s", safeArtist, safeTrack)
		for _, ext := range []string{".jpg", ".png", ".webp", ".gif"} {
			p := filepath.Join(cacheDir, base+ext)
			if info, err := os.Stat(p); err == nil && info.Size() > 0 {
				return p
			}
		}
	}
	if trackID != "" {
		hash := utils.HashString(trackID)
		prefix := fmt.Sprintf("cover_%x", hash)
		entries, err := os.ReadDir(cacheDir)
		if err == nil {
			for _, e := range entries {
				if !e.IsDir() && strings.HasPrefix(e.Name(), prefix) {
					return filepath.Join(cacheDir, e.Name())
				}
			}
		}
	}
	return ""
}
