package core

import (
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/audio/metadata"
)

type ISRCIndex struct {
	index     map[string]string
	outputDir string
	buildTime time.Time
	mu        sync.RWMutex
}

var (
	isrcIndexCache   = make(map[string]*ISRCIndex)
	isrcIndexCacheMu sync.RWMutex
	isrcBuildingMu   sync.Map
	isrcIndexTTL     = 5 * time.Minute
)

func GetISRCIndex(outputDir string) *ISRCIndex {
	isrcIndexCacheMu.RLock()
	idx, exists := isrcIndexCache[outputDir]
	isrcIndexCacheMu.RUnlock()

	if exists && time.Since(idx.buildTime) < isrcIndexTTL {
		return idx
	}

	buildLock, _ := isrcBuildingMu.LoadOrStore(outputDir, &sync.Mutex{})
	mu := buildLock.(*sync.Mutex)
	mu.Lock()
	defer mu.Unlock()

	isrcIndexCacheMu.RLock()
	idx, exists = isrcIndexCache[outputDir]
	isrcIndexCacheMu.RUnlock()

	if exists && time.Since(idx.buildTime) < isrcIndexTTL {
		return idx
	}

	return buildISRCIndex(outputDir)
}

func buildISRCIndex(outputDir string) *ISRCIndex {
	idx := &ISRCIndex{
		index:     make(map[string]string),
		outputDir: outputDir,
		buildTime: time.Now(),
	}

	if outputDir == "" {
		return idx
	}

	fileCount := 0

	filepath.Walk(outputDir, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		ext := strings.ToLower(filepath.Ext(path))
		if ext != ".flac" {
			return nil
		}
		meta, err := metadata.ReadMetadata(path)
		if err != nil || meta.ISRC == "" {
			return nil
		}
		idx.index[strings.ToUpper(meta.ISRC)] = path
		fileCount++
		return nil
	})

	isrcIndexCacheMu.Lock()
	isrcIndexCache[outputDir] = idx
	isrcIndexCacheMu.Unlock()

	return idx
}

func (idx *ISRCIndex) lookup(isrc string) (string, bool) {
	if isrc == "" {
		return "", false
	}
	idx.mu.RLock()
	defer idx.mu.RUnlock()
	path, exists := idx.index[strings.ToUpper(isrc)]
	return path, exists
}

func (idx *ISRCIndex) remove(isrc string) {
	if isrc == "" {
		return
	}
	idx.mu.Lock()
	defer idx.mu.Unlock()
	delete(idx.index, strings.ToUpper(isrc))
}

func (idx *ISRCIndex) Lookup(isrc string) (string, error) {
	path, _ := idx.lookup(isrc)
	return path, nil
}

func (idx *ISRCIndex) Add(isrc, filePath string) {
	if isrc == "" || filePath == "" {
		return
	}
	idx.mu.Lock()
	defer idx.mu.Unlock()
	idx.index[strings.ToUpper(isrc)] = filePath
}

func InvalidateISRCCache(outputDir string) {
	isrcIndexCacheMu.Lock()
	delete(isrcIndexCache, outputDir)
	isrcIndexCacheMu.Unlock()
}
