package cache

import "sync"

// TrackRef stores minimal track info keyed by ISRC for dedup.
type TrackRef struct {
	TrackID    string `json:"trackId"`
	Title      string `json:"title"`
	ArtistName string `json:"artistName"`
	AlbumName  string `json:"albumName"`
	Provider   string `json:"provider"`
}

// ISRCIndex is a thread-safe map of ISRC → TrackRef for dedup.
type ISRCIndex struct {
	mu    sync.RWMutex
	isrcs map[string]*TrackRef
}

// NewISRCIndex creates an empty ISRC index.
func NewISRCIndex() *ISRCIndex {
	return &ISRCIndex{isrcs: make(map[string]*TrackRef)}
}

// Add stores a track reference by its ISRC code.
func (idx *ISRCIndex) Add(isrc string, ref *TrackRef) {
	if isrc == "" {
		return
	}
	idx.mu.Lock()
	idx.isrcs[isrc] = ref
	idx.mu.Unlock()
}

// Lookup returns the track reference for an ISRC, if indexed.
func (idx *ISRCIndex) Lookup(isrc string) (*TrackRef, bool) {
	if isrc == "" {
		return nil, false
	}
	idx.mu.RLock()
	ref, ok := idx.isrcs[isrc]
	idx.mu.RUnlock()
	if !ok {
		return nil, false
	}
	return ref, true
}

// Has returns true if the ISRC is already indexed.
func (idx *ISRCIndex) Has(isrc string) bool {
	if isrc == "" {
		return false
	}
	idx.mu.RLock()
	_, ok := idx.isrcs[isrc]
	idx.mu.RUnlock()
	return ok
}

// Remove deletes an ISRC entry.
func (idx *ISRCIndex) Remove(isrc string) {
	if isrc == "" {
		return
	}
	idx.mu.Lock()
	delete(idx.isrcs, isrc)
	idx.mu.Unlock()
}

// Clear removes all entries.
func (idx *ISRCIndex) Clear() {
	idx.mu.Lock()
	idx.isrcs = make(map[string]*TrackRef)
	idx.mu.Unlock()
}

// Len returns the number of indexed ISRCs.
func (idx *ISRCIndex) Len() int {
	idx.mu.RLock()
	defer idx.mu.RUnlock()
	return len(idx.isrcs)
}
