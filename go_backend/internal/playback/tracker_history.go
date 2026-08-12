package playback

import (
	"sort"
)

// GetHistory returns recent plays, newest first.
func (t *Tracker) GetHistory(limit int) []PlayEvent {
	t.mu.RLock()
	defer t.mu.RUnlock()
	if limit < 1 || limit > len(t.history) {
		limit = len(t.history)
	}
	result := make([]PlayEvent, limit)
	for i := 0; i < limit; i++ {
		result[i] = t.history[len(t.history)-1-i]
	}
	return result
}

// PlayCount returns how many times a track has been played.
func (t *Tracker) PlayCount(trackID string) int {
	t.mu.RLock()
	defer t.mu.RUnlock()
	return t.playCounts[trackID]
}

// TopTracks returns the most played tracks.
func (t *Tracker) TopTracks(limit int) []string {
	t.mu.RLock()
	defer t.mu.RUnlock()
	type kv struct {
		Key   string
		Value int
	}
	var sorted []kv
	for k, v := range t.playCounts {
		sorted = append(sorted, kv{k, v})
	}
	sort.Slice(sorted, func(i, j int) bool {
		return sorted[i].Value > sorted[j].Value
	})
	if limit > len(sorted) {
		limit = len(sorted)
	}
	result := make([]string, limit)
	for i := 0; i < limit; i++ {
		result[i] = sorted[i].Key
	}
	return result
}

// TopArtists returns the most played artist IDs.
func (t *Tracker) TopArtists(limit int) []string {
	t.mu.RLock()
	defer t.mu.RUnlock()
	type kv struct {
		Key   string
		Value int
	}
	var sorted []kv
	for k, v := range t.artistCount {
		sorted = append(sorted, kv{k, v})
	}
	sort.Slice(sorted, func(i, j int) bool {
		return sorted[i].Value > sorted[j].Value
	})
	if limit > len(sorted) {
		limit = len(sorted)
	}
	result := make([]string, limit)
	for i := 0; i < limit; i++ {
		result[i] = sorted[i].Key
	}
	return result
}
