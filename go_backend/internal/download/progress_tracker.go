package download

import (
	"sync"
)

type Tracker struct {
	mu    sync.Mutex
	items map[string]*Progress
}

// NewTracker creates a progress tracker.
func NewTracker() *Tracker {
	return &Tracker{items: make(map[string]*Progress)}
}

// Add registers a new download progress entry.
func (t *Tracker) Add(itemID, title, provider string) {
	t.mu.Lock()
	t.items[itemID] = &Progress{
		ItemID:    itemID,
		Title:     title,
		TrackName: title,
		Status:    StatusQueued,
		Provider:  provider,
	}
	t.mu.Unlock()
}

// SetTrackInfo stores the resolved track name and artist for display.
func (t *Tracker) SetTrackInfo(itemID, trackName, artistName string) {
	t.mu.Lock()
	if p, ok := t.items[itemID]; ok {
		if trackName != "" {
			p.TrackName = trackName
			if p.Title == "" {
				p.Title = trackName
			}
		}
		if artistName != "" {
			p.ArtistName = artistName
		}
	}
	t.mu.Unlock()
}

// Update sets progress for an item.
func (t *Tracker) Update(itemID string, status Status, progress float64) {
	t.mu.Lock()
	if p, ok := t.items[itemID]; ok {
		p.Status = status
		p.Progress = progress
	}
	t.mu.Unlock()
}

// SetError sets error on a download. If the item is already StatusCompleted
// (a winning provider already finalized a playable or encrypted file), the
// error is recorded but the status is NOT downgraded — background goroutines
// for losing providers may call SetError after the winner already succeeded.
