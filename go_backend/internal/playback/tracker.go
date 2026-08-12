package playback

import (
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
	playCounts  map[string]int
	artistCount map[string]int
	lastPlayed  map[string]time.Time
}

// NewTracker creates a playback tracker.
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
