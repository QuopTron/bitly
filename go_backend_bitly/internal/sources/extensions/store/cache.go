package store

import (
	"encoding/json"
	"os"
	"path/filepath"
	"time"
)

func (s *Store) loadDiskCache() {
	if s.cacheDir == "" {
		return
	}
	cachePath := filepath.Join(s.cacheDir, cacheFileName)
	data, err := os.ReadFile(cachePath)
	if err != nil {
		return
	}
	var cacheData struct {
		Registry  storeRegistry `json:"registry"`
		CacheTime int64         `json:"cache_time"`
	}
	if err := json.Unmarshal(data, &cacheData); err != nil {
		return
	}
	s.mu.Lock()
	s.cache = &cacheData.Registry
	s.cacheTime = time.Unix(cacheData.CacheTime, 0)
	s.mu.Unlock()
}

func (s *Store) saveDiskCache() {
	if s.cacheDir == "" || s.cache == nil {
		return
	}
	s.mu.RLock()
	cacheData := struct {
		Registry  storeRegistry `json:"registry"`
		CacheTime int64         `json:"cache_time"`
	}{
		Registry:  *s.cache,
		CacheTime: s.cacheTime.Unix(),
	}
	s.mu.RUnlock()

	data, err := json.Marshal(cacheData)
	if err != nil {
		return
	}
	cachePath := filepath.Join(s.cacheDir, cacheFileName)
	if err := os.MkdirAll(filepath.Dir(cachePath), 0755); err != nil {
		return
	}
	os.WriteFile(cachePath, data, 0644)
}

func (s *Store) ClearCache() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.cache = nil
	s.cacheTime = time.Time{}
	if s.cacheDir != "" {
		cachePath := filepath.Join(s.cacheDir, cacheFileName)
		os.Remove(cachePath)
	}
}
