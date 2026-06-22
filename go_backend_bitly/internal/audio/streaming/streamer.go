package streaming

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
)

// Streamer handles HTTP audio streaming with range support.
type Streamer struct {
	musicDir string
}

// NewStreamer creates a new audio streamer.
func NewStreamer(musicDir string) *Streamer {
	return &Streamer{musicDir: musicDir}
}

// ServeAudio serves an audio file for streaming with HTTP range support.
func (s *Streamer) ServeAudio(w http.ResponseWriter, r *http.Request, relativePath string) {
	fullPath := filepath.Join(s.musicDir, relativePath)
	file, err := os.Open(fullPath)
	if err != nil {
		http.Error(w, "File not found", http.StatusNotFound)
		return
	}
	defer file.Close()

	stat, err := file.Stat()
	if err != nil {
		http.Error(w, "Internal server error", http.StatusInternalServerError)
		return
	}

	fileSize := stat.Size()
	ext := strings.ToLower(filepath.Ext(fullPath))
	mimeType := mimeForExt(ext)

	w.Header().Set("Accept-Ranges", "bytes")
	w.Header().Set("Content-Type", mimeType)

	rangeHeader := r.Header.Get("Range")
	if rangeHeader == "" {
		w.Header().Set("Content-Length", strconv.FormatInt(fileSize, 10))
		w.WriteHeader(http.StatusOK)
		io.Copy(w, file)
		return
	}

	// Parse Range: bytes=start-end
	rangeStr := strings.TrimPrefix(rangeHeader, "bytes=")
	parts := strings.SplitN(rangeStr, "-", 2)
	if len(parts) != 2 {
		http.Error(w, "Invalid range", http.StatusRequestedRangeNotSatisfiable)
		return
	}

	start, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		start = 0
	}

	var end int64
	if parts[1] != "" {
		end, err = strconv.ParseInt(parts[1], 10, 64)
		if err != nil {
			end = fileSize - 1
		}
	} else {
		end = fileSize - 1
	}

	if start > end || start >= fileSize {
		http.Error(w, "Range not satisfiable", http.StatusRequestedRangeNotSatisfiable)
		return
	}

	contentLength := end - start + 1
	w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", start, end, fileSize))
	w.Header().Set("Content-Length", strconv.FormatInt(contentLength, 10))
	w.WriteHeader(http.StatusPartialContent)

	file.Seek(start, io.SeekStart)
	io.CopyN(w, file, contentLength)
}

func mimeForExt(ext string) string {
	switch ext {
	case ".flac":
		return "audio/flac"
	case ".mp3":
		return "audio/mpeg"
	case ".m4a", ".aac":
		return "audio/mp4"
	case ".opus":
		return "audio/opus"
	case ".ogg":
		return "audio/ogg"
	case ".wav":
		return "audio/wav"
	case ".wma":
		return "audio/x-ms-wma"
	default:
		return "application/octet-stream"
	}
}
