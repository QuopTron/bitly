package gobackend

import (
	"crypto/sha256"
	"encoding/hex"
	"os"
	"path/filepath"
	"sort"
	"time"
)

// coverHash derives a stable 16-byte hex name from any key (URL, ISRC, id).
func hashPortada(key string) string {
	h := sha256.Sum256([]byte(key))
	return hex.EncodeToString(h[:16])
}

func statsDir(dir string) (bytes int64, count int) {
	if entries, err := os.ReadDir(dir); err == nil {
		for _, e := range entries {
			if e.IsDir() {
				continue
			}
			count++
			if info, err := e.Info(); err == nil {
				bytes += info.Size()
			}
		}
	}
	return
}

// coversLevelLimitMB returns the plan-based cap for the .covers dir. Covers
// are small but accumulate one per liked/downloaded track, so they get their
// own tighter budget instead of eating the stream-cache cap.
func limiteMBPortadas() int {
	switch userLevelLabel() {
	case "lifetime":
		return 1000
	case "premium":
		return 500
	default:
		return 50
	}
}

// evictCovers bounds the covers dir to the plan's covers cap, deleting the
// oldest files first (same policy as evictStreamCache). Runs after each new
// cover is saved and whenever the settings screen is opened.
func evictarPortadas(dir string) {
	limiteEviccionPortadas(dir, limiteMBPortadas())
}

// evictCoversLimit is evictCovers with an explicit cap (injectable for tests).
func limiteEviccionPortadas(dir string, limitMB int) {
	if limitMB <= 0 {
		return
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	type f struct {
		path string
		mod  time.Time
		size int64
	}
	var files []f
	var total int64
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		info, err := e.Info()
		if err != nil {
			continue
		}
		files = append(files, f{filepath.Join(dir, e.Name()), info.ModTime(), info.Size()})
		total += info.Size()
	}
	if len(files) == 0 {
		return
	}
	sort.Slice(files, func(i, j int) bool { return files[i].mod.Before(files[j].mod) })
	maxBytes := int64(limitMB) * 1024 * 1024
	const maxFiles = 5000
	for i := 0; i < len(files); i++ {
		remaining := len(files) - i
		if remaining <= maxFiles && total <= maxBytes {
			break
		}
		if os.Remove(files[i].path) == nil {
			total -= files[i].size
		}
	}
}

func userLevelLabel() string {
	if userMode == "free" {
		return "free"
	}
	if userMode == "lifetime" {
		return "lifetime"
	}
	if userMode != "" {
		return "premium"
	}
	if premiumChecker != nil && premiumChecker.IsPremium() {
		return "premium"
	}
	return "free"
}

func streamCacheLevelLimitMB() int {
	level := userLevelLabel()
	switch level {
	case "lifetime":
		return 5000
	case "premium":
		return 2000
	default:
		return 200
	}
}
