package metadata

import (
	"fmt"
	"os"
	"strings"
)

// ExtractLyrics extracts lyrics from an audio file or sidecar .lrc file.
func ExtractLyrics(filePath string) (string, error) {
	lower := strings.ToLower(filePath)

	if strings.HasSuffix(lower, ".flac") {
		lyrics, err := extractLyricsFromFlac(filePath)
		if err == nil && strings.TrimSpace(lyrics) != "" {
			return lyrics, nil
		}
		return extractLyricsFromSidecarLRC(filePath)
	}

	if strings.HasSuffix(lower, ".m4a") || strings.HasSuffix(lower, ".aac") {
		meta, err := ReadM4ATags(filePath)
		if err == nil && meta != nil && strings.TrimSpace(meta.Lyrics) != "" {
			return meta.Lyrics, nil
		}
		return extractLyricsFromSidecarLRC(filePath)
	}

	if strings.HasSuffix(lower, ".mp3") {
		meta, err := ReadID3Tags(filePath)
		if err == nil && meta != nil {
			if strings.TrimSpace(meta.Lyrics) != "" {
				return meta.Lyrics, nil
			}
			if looksLikeEmbeddedLyrics(meta.Comment) {
				return meta.Comment, nil
			}
		}
		return extractLyricsFromSidecarLRC(filePath)
	}

	if strings.HasSuffix(lower, ".opus") || strings.HasSuffix(lower, ".ogg") {
		meta, err := ReadOggVorbisComments(filePath)
		if err == nil && meta != nil {
			if strings.TrimSpace(meta.Lyrics) != "" {
				return meta.Lyrics, nil
			}
			if looksLikeEmbeddedLyrics(meta.Comment) {
				return meta.Comment, nil
			}
		}
		return extractLyricsFromSidecarLRC(filePath)
	}

	return extractLyricsFromSidecarLRC(filePath)
}

func extractLyricsFromFlac(filePath string) (string, error) {
	meta, err := ReadMetadata(filePath)
	if err != nil {
		return "", err
	}
	if strings.TrimSpace(meta.Lyrics) != "" {
		return meta.Lyrics, nil
	}
	return "", fmt.Errorf("no lyrics found in file")
}

func extractLyricsFromSidecarLRC(filePath string) (string, error) {
	ext := filepathExt(filePath)
	base := filePath[:len(filePath)-len(ext)]
	if strings.TrimSpace(base) == "" {
		return "", fmt.Errorf("no lyrics found in file")
	}
	lrcPath := base + ".lrc"
	data, err := os.ReadFile(lrcPath)
	if err != nil {
		return "", fmt.Errorf("no lyrics found in file")
	}
	lyrics := strings.TrimSpace(string(data))
	if lyrics == "" {
		return "", fmt.Errorf("no lyrics found in file")
	}
	return lyrics, nil
}

func looksLikeEmbeddedLyrics(value string) bool {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return false
	}
	lower := strings.ToLower(trimmed)
	if strings.Contains(lower, "[ar:") || strings.Contains(lower, "[ti:") {
		return true
	}
	if strings.Contains(trimmed, "\n") && strings.Contains(trimmed, "[") && strings.Contains(trimmed, "]") {
		return true
	}
	return false
}
