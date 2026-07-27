package playback

import (
	"math"
	"sort"
	"sync"
	"time"
)

// Tracker manages playback state, queue, and history.
// Thread-safe. All data is in-memory (Flutter handles persistence via Drift).
type Tracker struct {
	mu          sync.RWMutex
	nowPlaying  *TrackInfo
	queue       []QueueItem
	history     []PlayEvent
	maxHistory  int
	playCounts  map[string]int       // trackID -> play count
	artistCount map[string]int       // artistID -> play count
	lastPlayed  map[string]time.Time // trackID -> last played time
}

// NewTracker creates a playback tracker.
// maxHistory controls how many events to keep in memory.
func NewTracker(maxHistory int) *Tracker {
	if maxHistory < 1 {
		maxHistory = 200
	}
	return &Tracker{
		maxHistory:  maxHistory,
		playCounts:  make(map[string]int),
		artistCount: make(map[string]int),
		lastPlayed:  make(map[string]time.Time),
	}
}

// NowPlaying returns the currently playing track, or nil.
func (t *Tracker) NowPlaying() *TrackInfo {
	t.mu.RLock()
	defer t.mu.RUnlock()
	return t.nowPlaying
}

// SetNowPlaying updates the currently playing track.
func (t *Tracker) SetNowPlaying(track *TrackInfo) {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.nowPlaying = track
	if track != nil {
		t.lastPlayed[track.ID] = time.Now()
	}
}

// MarkPlayed records a track as fully played and adds to history.
func (t *Tracker) MarkPlayed(track *TrackInfo, durationSeconds int) {
	t.mu.Lock()
	defer t.mu.Unlock()

	event := PlayEvent{
		Track:     *track,
		Timestamp: time.Now().Unix(),
		Duration:  durationSeconds,
	}
	t.history = append(t.history, event)
	if len(t.history) > t.maxHistory {
		t.history = t.history[len(t.history)-t.maxHistory:]
	}

	t.playCounts[track.ID]++
	if track.ArtistID != "" {
		t.artistCount[track.ArtistID]++
	}
	t.lastPlayed[track.ID] = time.Now()
	if t.nowPlaying != nil && t.nowPlaying.ID == track.ID {
		t.nowPlaying = nil
	}
}

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

// Queue returns the current playback queue.
func (t *Tracker) Queue() []QueueItem {
	t.mu.RLock()
	defer t.mu.RUnlock()
	result := make([]QueueItem, len(t.queue))
	copy(result, t.queue)
	return result
}

// AddToQueue adds a track to the end of the queue.
func (t *Tracker) AddToQueue(track *TrackInfo, addedBy string) {
	t.mu.Lock()
	defer t.mu.Unlock()
	item := QueueItem{
		Track:    *track,
		AddedBy:  addedBy,
		Position: len(t.queue),
	}
	t.queue = append(t.queue, item)
}

// RemoveFromQueue removes a track from queue by position.
func (t *Tracker) RemoveFromQueue(position int) bool {
	t.mu.Lock()
	defer t.mu.Unlock()
	if position < 0 || position >= len(t.queue) {
		return false
	}
	t.queue = append(t.queue[:position], t.queue[position+1:]...)
	for i := range t.queue {
		t.queue[i].Position = i
	}
	return true
}

// ClearQueue empties the queue.
func (t *Tracker) ClearQueue() {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.queue = nil
}

// ReorderQueue moves a track from oldPos to newPos.
func (t *Tracker) ReorderQueue(oldPos, newPos int) bool {
	t.mu.Lock()
	defer t.mu.Unlock()
	if oldPos < 0 || oldPos >= len(t.queue) || newPos < 0 || newPos >= len(t.queue) {
		return false
	}
	item := t.queue[oldPos]
	t.queue = append(t.queue[:oldPos], t.queue[oldPos+1:]...)
	t.queue = append(t.queue[:newPos], append([]QueueItem{item}, t.queue[newPos:]...)...)
	for i := range t.queue {
		t.queue[i].Position = i
	}
	return true
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

// Stats returns playback statistics.
func (t *Tracker) Stats() map[string]interface{} {
	t.mu.RLock()
	defer t.mu.RUnlock()
	totalDuration := 0
	for _, e := range t.history {
		totalDuration += e.Duration
	}
	uniqueTracks := len(t.playCounts)
	uniqueArtists := len(t.artistCount)
	return map[string]interface{}{
		"totalPlays":    len(t.history),
		"uniqueTracks":  uniqueTracks,
		"uniqueArtists": uniqueArtists,
		"totalDuration": totalDuration,
		"queueLength":   len(t.queue),
	}
}

// GetRecommendations returns track IDs from history to recommend.
// Simple algorithm: top artists + recently played tracks.
func (t *Tracker) GetRecommendations(limit int) []PlayEvent {
	t.mu.RLock()
	defer t.mu.RUnlock()
	if len(t.history) == 0 {
		return nil
	}

	// Score each play event based on recency and play count
	type scored struct {
		event PlayEvent
		score float64
	}
	var scoredEvents []scored
	now := time.Now()
	seen := make(map[string]bool)

	for _, e := range t.history {
		if seen[e.Track.ID] {
			continue
		}
		seen[e.Track.ID] = true

		hoursAgo := now.Sub(time.Unix(e.Timestamp, 0)).Hours()
		recencyScore := math.Exp(-hoursAgo / 48.0) // decays over 48h
		freqScore := math.Log(float64(t.playCounts[e.Track.ID]) + 1)
		score := recencyScore*0.6 + freqScore*0.4

		scoredEvents = append(scoredEvents, scored{e, score})
	}

	sort.Slice(scoredEvents, func(i, j int) bool {
		return scoredEvents[i].score > scoredEvents[j].score
	})

	if limit > len(scoredEvents) {
		limit = len(scoredEvents)
	}
	result := make([]PlayEvent, limit)
	for i := 0; i < limit; i++ {
		result[i] = scoredEvents[i].event
	}
	return result
}
