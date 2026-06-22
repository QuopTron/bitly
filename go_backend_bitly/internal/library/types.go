package library

import (
	"sync"

	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

type LibraryScanProgress struct {
	TotalFiles   int     `json:"total_files"`
	ScannedFiles int     `json:"scanned_files"`
	CurrentFile  string  `json:"current_file"`
	ErrorCount   int     `json:"error_count"`
	ProgressPct  float64 `json:"progress_pct"`
	IsComplete   bool    `json:"is_complete"`
}

type IncrementalScanResult struct {
	Scanned      []database.LibraryScanResult `json:"scanned"`
	DeletedPaths []string                     `json:"deletedPaths"`
	SkippedCount int                          `json:"skippedCount"`
	TotalFiles   int                          `json:"totalFiles"`
}

var (
	libraryScanProgress   LibraryScanProgress
	libraryScanProgressMu sync.RWMutex
	libraryScanCancel     chan struct{}
	libraryScanCancelMu   sync.Mutex
	libraryCoverCacheDir  string
	libraryCoverCacheMu   sync.RWMutex
)

var supportedAudioFormats = map[string]bool{
	".flac": true,
	".m4a":  true,
	".mp3":  true,
	".opus": true,
	".ogg":  true,
	".ape":  true,
	".wv":   true,
	".mpc":  true,
	".cue":  true,
}

type libraryAudioFileInfo struct {
	path    string
	modTime int64
}

var Log = func(format string, args ...interface{}) {}

func SetLogFn(logFn func(format string, args ...interface{})) {
	Log = logFn
}

func SetLibraryCoverCacheDir(cacheDir string) {
	libraryCoverCacheMu.Lock()
	libraryCoverCacheDir = cacheDir
	libraryCoverCacheMu.Unlock()
}
