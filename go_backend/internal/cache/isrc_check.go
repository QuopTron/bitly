package cache

import (
	"path/filepath"
	"strings"
	"sync"
)

// CheckFilesExistParallel checks which tracks already exist on disk by ISRC.
// Returns a map of ISRC → file path for existing files.
func (idx *ISRCIndex) CheckFilesExistParallel(outputDir string, isrcs []string) map[string]string {
	if len(isrcs) == 0 {
		return nil
	}

	type checkResult struct {
		isrc string
		path string
	}

	results := make(chan checkResult, len(isrcs))
	var wg sync.WaitGroup

	sem := make(chan struct{}, parallelWorkers)
	for _, isrc := range isrcs {
		wg.Add(1)
		sem <- struct{}{}
		go func(isrc string) {
			defer wg.Done()
			defer func() { <-sem }()

			idx.mutex.RLock()
			ref, ok := idx.indiceISRC[isrc]
			idx.mutex.RUnlock()

			if ok && ref != nil {
				// Comprueba si el archivo todavía existe
				if ref.TrackID != "" {
					// Search for file by track ID pattern
					found := findFileByTrackID(outputDir, ref.TrackID)
					if found != "" {
						results <- checkResult{isrc, found}
						return
					}
				}
			}

			// Fallback: scan directory for ISRC in metadata
			path := scanForISRC(outputDir, isrc)
			if path != "" {
				results <- checkResult{isrc, path}
			}
		}(isrc)
	}

	go func() {
		wg.Wait()
		close(results)
	}()

	existing := make(map[string]string)
	for r := range results {
		existing[r.isrc] = r.path
	}
	return existing
}

// AddToISRCIndex adds a single file to the index.
func (idx *ISRCIndex) AddToISRCIndex(filePath string) {
	isrc, ref := extractISRCFromFile(filePath)
	if isrc != "" && ref != nil {
		idx.Add(isrc, ref)
	}
}

// InvalidateISRCCache removes cached file stats for a directory so next
// BuildIndex re-scans everything.
func (idx *ISRCIndex) InvalidateISRCCache(dir string) {
	idx.mutex.Lock()
	defer idx.mutex.Unlock()
	prefix := filepath.Clean(dir) + string(filepath.Separator)
	for path := range idx.cacheArchivos {
		if strings.HasPrefix(path, prefix) {
			delete(idx.cacheArchivos, path)
		}
	}
}

// ═══════════════════════════════════════════════════════════════════════
// Native ISRC extraction (FLAC, MP3, M4A, Ogg)
// ═══════════════════════════════════════════════════════════════════════
