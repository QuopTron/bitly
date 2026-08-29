package download

import (
	"io"
	"log"
	"os"
	"path/filepath"
	"sync"
)

// ═══════════════════════════════════════════════════════════════════════
// Download Output Staging — atomic writes to prevent corruption
// ═══════════════════════════════════════════════════════════════════════

// StagingManager serializes concurrent downloads to the same final path
// via per-path locks, and writes through a .partial staging file that is
// atomically renamed to the target on success.
type StagingManager struct {
	mu    sync.Mutex
	locks map[string]*sync.Mutex
}

// NewStagingManager creates a new staging manager.
func NewStagingManager() *StagingManager {
	return &StagingManager{locks: make(map[string]*sync.Mutex)}
}

func (sm *StagingManager) getLock(finalPath string) *sync.Mutex {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	key := filepath.Clean(finalPath)
	l, ok := sm.locks[key]
	if !ok {
		l = &sync.Mutex{}
		sm.locks[key] = l
	}
	return l
}

// StagePath returns the temporary staging path (.partial) for a given final path.
func StagePath(finalPath string) string {
	return finalPath + ".partial"
}

// WriteStaged downloads data from src to finalPath through a staging file.
// Concurrent writes to the same finalPath are serialized. On success the
// staging file is atomically renamed to finalPath.
func (sm *StagingManager) WriteStaged(finalPath string, src io.Reader) (string, error) {
	lock := sm.getLock(finalPath)
	lock.Lock()
	defer lock.Unlock()

	dir := filepath.Dir(finalPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return "", err
	}

	stagingPath := StagePath(finalPath)

	tmp, err := os.Create(stagingPath)
	if err != nil {
		return "", err
	}
	defer func() {
		// On failure, clean up the staging file
		tmp.Close()
		os.Remove(stagingPath)
	}()

	if _, err := io.Copy(tmp, src); err != nil {
		return "", err
	}

	// fsync before rename for crash safety
	if err := tmp.Sync(); err != nil {
		return "", err
	}
	if err := tmp.Close(); err != nil {
		return "", err
	}

	// Atomic rename
	if err := os.Rename(stagingPath, finalPath); err != nil {
		// Cross-device rename fallback
		if in, inErr := os.Open(stagingPath); inErr == nil {
			out, outErr := os.Create(finalPath)
			if outErr == nil {
				_, _ = io.Copy(out, in)
				out.Sync()
				out.Close()
				in.Close()
				os.Remove(stagingPath)
			} else {
				in.Close()
				return "", outErr
			}
		} else {
			return "", inErr
		}
	}

	log.Printf("[staging] %s -> %s", stagingPath, finalPath)
	return finalPath, nil
}

// WriteStagedBytes writes a byte slice to finalPath through staging.
func (sm *StagingManager) WriteStagedBytes(finalPath string, data []byte) (string, error) {
	lock := sm.getLock(finalPath)
	lock.Lock()
	defer lock.Unlock()

	dir := filepath.Dir(finalPath)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return "", err
	}

	stagingPath := StagePath(finalPath)

	if err := os.WriteFile(stagingPath, data, 0644); err != nil {
		os.Remove(stagingPath)
		return "", err
	}

	if err := os.Rename(stagingPath, finalPath); err != nil {
		os.Remove(stagingPath)
		return "", err
	}

	return finalPath, nil
}

// CleanupStaging removes any leftover .partial files in the given directory.
func CleanupStaging(dir string) int {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return 0
	}
	removed := 0
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		if filepath.Ext(e.Name()) == ".partial" {
			path := filepath.Join(dir, e.Name())
			if err := os.Remove(path); err == nil {
				removed++
			}
		}
	}
	return removed
}
