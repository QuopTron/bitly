package cue

import (
	"os"
	"path/filepath"
	"strings"
)

func ResolveCueAudioPath(cuePath string, cueFileName string) string {
	cueDir := filepath.Dir(cuePath)

	candidate := filepath.Join(cueDir, cueFileName)
	if _, err := os.Stat(candidate); err == nil {
		return candidate
	}

	baseName := strings.TrimSuffix(cueFileName, filepath.Ext(cueFileName))
	commonExts := []string{".flac", ".wav", ".ape", ".mp3", ".ogg", ".wv", ".m4a"}
	for _, ext := range commonExts {
		candidate = filepath.Join(cueDir, baseName+ext)
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
		candidate = filepath.Join(cueDir, baseName+strings.ToUpper(ext))
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
	}

	cueBase := strings.TrimSuffix(filepath.Base(cuePath), filepath.Ext(cuePath))
	for _, ext := range commonExts {
		candidate = filepath.Join(cueDir, cueBase+ext)
		if _, err := os.Stat(candidate); err == nil {
			return candidate
		}
	}

	entries, err := os.ReadDir(cueDir)
	if err == nil {
		audioExts := map[string]bool{
			".flac": true, ".wav": true, ".ape": true, ".mp3": true,
			".ogg": true, ".wv": true, ".m4a": true, ".aiff": true,
		}
		var audioFiles []string
		for _, entry := range entries {
			if entry.IsDir() {
				continue
			}
			ext := strings.ToLower(filepath.Ext(entry.Name()))
			if audioExts[ext] {
				audioFiles = append(audioFiles, filepath.Join(cueDir, entry.Name()))
			}
		}
		if len(audioFiles) == 1 {
			return audioFiles[0]
		}
	}

	return ""
}
