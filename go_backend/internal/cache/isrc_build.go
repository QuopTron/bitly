package cache

import (
	"log"
	"os"
	"path/filepath"
	"sync"
	"time"
)

// ═══════════════════════════════════════════════════════════════════════
// Parallel file scanning with incremental rebuild
// ═══════════════════════════════════════════════════════════════════════

const (
	parallelWorkers   = 4
	indexFreshnessTTL = 5 * time.Minute
	maxIndexAge       = 10 * time.Minute
)

// BuildIndex scans a directory tree in parallel and extracts ISRCs from
// audio files. Incremental: only re-parses files that changed since last build.
func (idx *ISRCIndex) BuildIndex(rootDir string) error {
	idx.mutexRebuild.Lock()
	if idx.reconstruyendo {
		idx.mutexRebuild.Unlock()
		return nil
	}
	idx.reconstruyendo = true
	idx.mutexRebuild.Unlock()
	defer func() {
		idx.mutexRebuild.Lock()
		idx.reconstruyendo = false
		idx.ultimaConstruccion = time.Now()
		idx.mutexRebuild.Unlock()
	}()

	start := time.Now()

	// Collect all audio files
	var files []string
	_ = filepath.Walk(rootDir, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		if isAudioFile(path) {
			files = append(files, path)
		}
		return nil
	})

	if len(files) == 0 {
		return nil
	}

	// Determine which files need re-scanning (incremental)
	var toScan []string
	idx.mutex.RLock()
	for _, f := range files {
		info, err := os.Stat(f)
		if err != nil {
			continue
		}
		cached, exists := idx.cacheArchivos[f]
		if !exists || cached.tamano != info.Size() || !cached.horaMod.Equal(info.ModTime()) {
			toScan = append(toScan, f)
		}
	}
	idx.mutex.RUnlock()

	if len(toScan) == 0 {
		log.Printf("[isrc-index] incremental: no changes in %d files", len(files))
		return nil
	}

	// Scan in parallel
	type result struct {
		path string
		isrc string
		ref  *TrackRef
	}

	jobs := make(chan string, len(toScan))
	results := make(chan result, len(toScan))
	var wg sync.WaitGroup

	for w := 0; w < parallelWorkers; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for path := range jobs {
				isrc, ref := extractISRCFromFile(path)
				if isrc != "" && ref != nil {
					results <- result{path, isrc, ref}
				}
			}
		}()
	}

	go func() {
		for _, f := range toScan {
			jobs <- f
		}
		close(jobs)
	}()

	go func() {
		wg.Wait()
		close(results)
	}()

	// Collect results
	newCount := 0
	for r := range results {
		idx.mutex.Lock()
		idx.indiceISRC[r.isrc] = r.ref
		info, err := os.Stat(r.path)
		if err == nil {
			idx.cacheArchivos[r.path] = statsArchivo{tamano: info.Size(), horaMod: info.ModTime()}
		}
		idx.mutex.Unlock()
		newCount++
	}

	log.Printf("[isrc-index] built %d ISRCs from %d files (%d new/changed) in %v",
		idx.Len(), len(files), newCount, time.Since(start).Round(time.Millisecond))
	return nil
}

// PreBuildIndex triggers a proactive index build in the background.
func (idx *ISRCIndex) PreBuildIndex(rootDir string) {
	go func() {
		if err := idx.BuildIndex(rootDir); err != nil {
			log.Printf("[isrc-index] prebuild error: %v", err)
		}
	}()
}
