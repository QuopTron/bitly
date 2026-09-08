package gobackend

import (
	"encoding/json"
	"os"
	"path/filepath"
	"time"
)

// streamFailDiskGetLocked loads [key] from the persisted cache if it is still
// within streamFailDiskTTL. Caller must hold streamFailMu.
func streamFailDiskGetLocked(key string) (streamFailEntry, bool) {
	path := streamFailPersistPathLocked()
	if path == "" {
		return streamFailEntry{}, false
	}
	entries, err := streamFailDiskReadLocked(path)
	if err != nil {
		return streamFailEntry{}, false
	}
	e, ok := entries[key]
	if !ok {
		return streamFailEntry{}, false
	}
	if time.Since(e.at) > streamFailDiskTTL {
		return streamFailEntry{}, false
	}
	return e, true
}

// streamFailDiskSetLocked persists [entry] under [key]. Caller holds streamFailMu.
func streamFailDiskSetLocked(key string, entry streamFailEntry) {
	path := streamFailPersistPathLocked()
	if path == "" {
		return
	}
	entries, err := streamFailDiskReadLocked(path)
	if err != nil {
		entries = map[string]streamFailEntry{}
	}
	// Bounded size: keep the most recent 400 failures so the JSON never
	// grows unbounded on long browsing sessions.
	if len(entries) >= 400 && entries[key].at.IsZero() {
		oldestKey := ""
		oldest := time.Time{}
		for k, v := range entries {
			if oldestKey == "" || v.at.Before(oldest) {
				oldestKey = k
				oldest = v.at
			}
		}
		if oldestKey != "" {
			delete(entries, oldestKey)
		}
	}
	entries[key] = entry
	streamFailDiskWriteLocked(path, entries)
}

// streamFailDiskClearLocked removes [key] from the persisted cache. Caller
// holds streamFailMu.
func streamFailDiskClearLocked(key string) {
	path := streamFailPersistPathLocked()
	if path == "" {
		return
	}
	entries, err := streamFailDiskReadLocked(path)
	if err != nil {
		return
	}
	if _, ok := entries[key]; !ok {
		return
	}
	delete(entries, key)
	streamFailDiskWriteLocked(path, entries)
}

// streamFailDiskEntry is the JSON-safe (exported fields) form of a persisted
// failure. encoding/json ignores unexported fields, so the live entry type
// cannot be marshaled directly.
type streamFailDiskEntry struct {
	At        time.Time `json:"at"`
	Err       string    `json:"err"`
	ErrorType string    `json:"errorType"`
	Service   string    `json:"service"`
}

// streamFailDiskReadLocked reads the persisted fail cache from disk. Caller
// must hold streamFailMu.
func streamFailDiskReadLocked(path string) (map[string]streamFailEntry, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var raw map[string]streamFailDiskEntry
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, err
	}
	out := make(map[string]streamFailEntry, len(raw))
	for k, v := range raw {
		out[k] = streamFailEntry{at: v.At, err: v.Err, errorType: v.ErrorType, service: v.Service}
	}
	return out, nil
}

// streamFailDiskWriteLocked writes the persisted fail cache to disk
// atomically (temp + rename). Caller holds streamFailMu.
func streamFailDiskWriteLocked(path string, entries map[string]streamFailEntry) {
	if path == "" {
		return
	}
	encodable := make(map[string]streamFailDiskEntry, len(entries))
	for k, v := range entries {
		if time.Since(v.at) <= streamFailDiskTTL {
			encodable[k] = streamFailDiskEntry{
				At:        v.at,
				Err:       v.err,
				ErrorType: v.errorType,
				Service:   v.service,
			}
		}
	}
	data, err := json.Marshal(encodable)
	if err != nil {
		return
	}
	tmp := path + ".tmp"
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return
	}
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return
	}
	_ = os.Rename(tmp, path)
}

// streamFailErrorJSON rebuilds the RPC error payload from a cached entry.
func streamFailErrorJSON(e streamFailEntry) string {
	mp := map[string]interface{}{"error": e.err}
	if e.errorType != "" {
		mp["errorType"] = e.errorType
	}
	if e.service != "" {
		mp["service"] = e.service
	}
	data, _ := json.Marshal(mp)
	return string(data)
}
