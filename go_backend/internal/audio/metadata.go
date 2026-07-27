// Package audio handles reading/writing audio metadata (tags, covers),
// format conversion, and audio analysis (replaygain, duration).
package audio

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Metadata holds parsed tag data from an audio file.
type Metadata struct {
	Title       string `json:"title"`
	Artist      string `json:"artist"`
	Album       string `json:"album"`
	AlbumArtist string `json:"albumArtist"`
	TrackNumber int    `json:"trackNumber"`
	TrackTotal  int    `json:"trackTotal"`
	DiscNumber  int    `json:"discNumber"`
	Year        int    `json:"year"`
	Genre       string `json:"genre"`
	ISRC        string `json:"isrc"`
	DurationMs  int    `json:"durationMs"`
	SampleRate  int    `json:"sampleRate"`
	BitDepth    int    `json:"bitDepth"`
	Bitrate     int    `json:"bitrate"`
	Format      string `json:"format"` // flac, mp3, m4a, ogg, wav, aiff
	HasCover    bool   `json:"hasCover"`
	FilePath    string `json:"filePath"`
	FileSize    int64  `json:"fileSize"`
}

// ReadFileMetadata reads tags from an audio file based on its extension.
func ReadFileMetadata(filePath string) (*Metadata, error) {
	info, err := os.Stat(filePath)
	if err != nil {
		return nil, err
	}

	ext := strings.ToLower(filepath.Ext(filePath))
	meta := &Metadata{
		FilePath: filePath,
		FileSize: info.Size(),
		Format:   strings.TrimPrefix(ext, "."),
	}

	switch ext {
	case ".flac":
		return readFLAC(filePath, meta)
	case ".mp3":
		return readMP3(filePath, meta)
	case ".m4a", ".mp4", ".m4b":
		return readMP4(filePath, meta)
	case ".ogg", ".opus":
		return readOGG(filePath, meta)
	case ".wav":
		return readWAV(filePath, meta)
	case ".aiff", ".aif":
		return readAIFF(filePath, meta)
	default:
		return nil, fmt.Errorf("audio: unsupported format %s", ext)
	}
}
