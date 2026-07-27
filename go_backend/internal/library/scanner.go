// Package library scans and manages the local music library.
package library

import (
	"os"
	"path/filepath"
	"sync"

	"github.com/zarz/bitly/go_backend/internal/audio"
)

// Entry represents a single library entry (file).
type Entry struct {
	FilePath string        `json:"filePath"`
	Metadata *audio.Metadata `json:"metadata,omitempty"`
	Size     int64         `json:"size"`
}

// Stats holds library statistics.
type Stats struct {
	TotalFiles   int   `json:"totalFiles"`
	TotalSize    int64 `json:"totalSize"`
	TotalArtists int   `json:"totalArtists"`
	TotalAlbums  int   `json:"totalAlbums"`
	TotalTracks  int   `json:"totalTracks"`
	DurationMs   int64 `json:"durationMs"`
}

// Library manages the local music collection.
type Library struct {
	mu      sync.Mutex
	entries []Entry
}

// New creates an empty library.
func New() *Library {
	return &Library{}
}

// Scan scans a directory for audio files.
func (l *Library) Scan(directory string) ([]Entry, error) {
	var entries []Entry
	var mu sync.Mutex
	var wg sync.WaitGroup

	audioExts := map[string]bool{
		".flac": true, ".mp3": true, ".m4a": true,
		".ogg": true, ".opus": true, ".wav": true, ".aiff": true,
	}

	err := filepath.Walk(directory, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		if !audioExts[filepath.Ext(path)] {
			return nil
		}

		wg.Add(1)
		go func(p string, fi os.FileInfo) {
			defer wg.Done()
			entry := Entry{FilePath: p, Size: fi.Size()}
			meta, err := audio.ReadFileMetadata(p)
			if err == nil {
				entry.Metadata = meta
			}
			mu.Lock()
			entries = append(entries, entry)
			mu.Unlock()
		}(path, info)

		return nil
	})

	wg.Wait()
	if err != nil {
		return entries, err
	}

	l.mu.Lock()
	l.entries = entries
	l.mu.Unlock()
	return entries, nil
}

// GetStats calculates library statistics.
func (l *Library) GetStats() Stats {
	l.mu.Lock()
	defer l.mu.Unlock()

	var s Stats
	artists := make(map[string]bool)
	albums := make(map[string]bool)

	for _, e := range l.entries {
		s.TotalFiles++
		s.TotalSize += e.Size
		if e.Metadata != nil {
			s.TotalTracks++
			s.DurationMs += int64(e.Metadata.DurationMs)
			if e.Metadata.Artist != "" {
				artists[e.Metadata.Artist] = true
			}
			if e.Metadata.Album != "" {
				albums[e.Metadata.Album+e.Metadata.Artist] = true
			}
		}
	}
	s.TotalArtists = len(artists)
	s.TotalAlbums = len(albums)
	return s
}

// GetEntries returns all library entries.
func (l *Library) GetEntries() []Entry {
	l.mu.Lock()
	defer l.mu.Unlock()
	result := make([]Entry, len(l.entries))
	copy(result, l.entries)
	return result
}
