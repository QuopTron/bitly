package download

import (
	"path/filepath"
	"sync"
)

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
