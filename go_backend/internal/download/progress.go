package download

import (
	"sync"
)

// Status represents download progress state.
type Status int

const (
	StatusQueued   Status = iota
	StatusDownloading
	StatusProcessing
	StatusCompleted
	StatusFailed
	StatusCancelled
)

func (s Status) String() string {
	switch s {
	case StatusQueued:
		return "queued"
	case StatusDownloading:
		return "downloading"
	case StatusProcessing:
		return "processing"
	case StatusCompleted:
		return "completed"
	case StatusFailed:
		return "failed"
	case StatusCancelled:
		return "cancelled"
	default:
		return "unknown"
	}
}

// Progress holds download progress for a single item.
type Progress struct {
	ItemID      string  `json:"itemId"`
	Title       string  `json:"title"`
	Status      Status  `json:"status"`
	Progress    float64 `json:"progress"` // 0.0 to 1.0
	BytesDone   int64   `json:"bytesDone"`
	BytesTotal  int64   `json:"bytesTotal"`
	Error       string  `json:"error,omitempty"`
	Provider    string  `json:"provider"`
	OutputPath  string  `json:"outputPath,omitempty"`
}

// Tracker maintains progress of all active downloads.
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
		ItemID:   itemID,
		Title:    title,
		Status:   StatusQueued,
		Provider: provider,
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

// SetError sets error on a download.
func (t *Tracker) SetError(itemID, errMsg string) {
	t.mu.Lock()
	if p, ok := t.items[itemID]; ok {
		p.Status = StatusFailed
		p.Error = errMsg
	}
	t.mu.Unlock()
}

// SetOutputPath sets the final file path.
func (t *Tracker) SetOutputPath(itemID, path string) {
	t.mu.Lock()
	if p, ok := t.items[itemID]; ok {
		p.OutputPath = path
		p.Status = StatusCompleted
		p.Progress = 1.0
	}
	t.mu.Unlock()
}

// Get returns progress for an item.
func (t *Tracker) Get(itemID string) *Progress {
	t.mu.Lock()
	defer t.mu.Unlock()
	if p, ok := t.items[itemID]; ok {
		cp := *p
		return &cp
	}
	return nil
}

// GetAll returns progress for all items.
func (t *Tracker) GetAll() []Progress {
	t.mu.Lock()
	defer t.mu.Unlock()
	result := make([]Progress, 0, len(t.items))
	for _, p := range t.items {
		result = append(result, *p)
	}
	return result
}

// Remove deletes a progress entry.
func (t *Tracker) Remove(itemID string) {
	t.mu.Lock()
	delete(t.items, itemID)
	t.mu.Unlock()
}
