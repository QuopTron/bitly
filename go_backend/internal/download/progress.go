package download

import (
	"encoding/json"
	"log"
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

// MarshalJSON serializes the status as its stable string form (e.g.
// "downloading") instead of the raw integer enum value. The Flutter
// DownloadCubit polling contract compares status against strings
// ('completed', 'downloading', 'failed', 'cancelled', ...), so sending the
// int here made every poll throw a cast error on the client and the dot
// stayed orange forever even when the download had finished.
func (s Status) MarshalJSON() ([]byte, error) {
	return json.Marshal(s.String())
}

// Progress holds download progress for a single item.
type Progress struct {
	ItemID     string  `json:"itemId"`
	Title      string  `json:"title"`
	TrackName  string  `json:"track_name,omitempty"`
	ArtistName string  `json:"artist_name,omitempty"`
	Status     Status  `json:"status"`
	Progress   float64 `json:"progress"` // 0.0 to 1.0
	BytesDone  int64   `json:"bytesDone"`
	BytesTotal int64   `json:"bytesTotal"`
	Error      string  `json:"error,omitempty"`
	Provider   string  `json:"provider"`
	OutputPath string  `json:"outputPath,omitempty"`
	// Encrypted marks an output file that is a DRM/encrypted stream (not yet
	// playable). ClientDecrypt is true when the backend could not decrypt it
	// here (no CLI ffmpeg, e.g. Android) so the client must decrypt it
	// (ffmpeg-kit) before playback; DecryptionKey / OutputExtension carry the
	// key and the container extension of the decrypted output; InputFormat is
	// the encrypted source container (e.g. "mov") for the decrypt step.
	Encrypted       bool   `json:"encrypted,omitempty"`
	ClientDecrypt   bool   `json:"clientDecrypt,omitempty"`
	DecryptionKey   string `json:"decryptionKey,omitempty"`
	OutputExtension string `json:"outputExtension,omitempty"`
	InputFormat     string `json:"inputFormat,omitempty"`
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
func (t *Tracker) SetError(itemID, errMsg string) {
	t.mu.Lock()
	if p, ok := t.items[itemID]; ok {
		if p.Status == StatusCompleted {
			log.Printf("[tracker] SetError(%s, %s) BLOCKED (completed, path=%s)", itemID, errMsg, p.OutputPath)
			t.mu.Unlock()
			return
		}
		log.Printf("[tracker] SetError(%s, %s) prevStatus=%v outputPath=%s", itemID, errMsg, p.Status, p.OutputPath)
		p.Status = StatusFailed
		p.Error = errMsg
	} else {
		log.Printf("[tracker] SetError(%s, %s) — item NOT found!", itemID, errMsg)
	}
	t.mu.Unlock()
}

// SetOutputPath sets the final file path.
// If the item is already marked as encrypted (a higher-quality provider
// already won the race), do NOT overwrite — a last-resort provider
// (soundcloud) finalizing later would replace the encrypted FLAC path
// with an MP3, causing the client-side decrypt to fail on the wrong file.
func (t *Tracker) SetOutputPath(itemID, path string) {
	t.mu.Lock()
	if p, ok := t.items[itemID]; ok {
		if p.Encrypted && p.DecryptionKey != "" {
			// An exact provider (amazon/qobuz) already set an encrypted
			// output. A last-resort provider finalizing later must NOT
			// overwrite the path — keep the encrypted file so the client
			// can decrypt it. Only update the status.
			log.Printf("[tracker] SetOutputPath(%s, %s) BLOCKED (encrypted already set)", itemID, path)
			p.Status = StatusCompleted
			p.Progress = 1.0
		} else {
			log.Printf("[tracker] SetOutputPath(%s, %s)", itemID, path)
			p.OutputPath = path
			p.Status = StatusCompleted
			p.Progress = 1.0
		}
	} else {
		log.Printf("[tracker] SetOutputPath(%s, %s) — item NOT found in tracker!", itemID, path)
	}
	t.mu.Unlock()
}

// SetEncryptedOutput marks the item completed with an encrypted/DRM file that
// the client must decrypt (ffmpeg-kit) before playback — used when the backend
// has no CLI ffmpeg to decrypt it (e.g. Android).
func (t *Tracker) SetEncryptedOutput(itemID, path, key, ext, inFmt string) {
	t.mu.Lock()
	defer t.mu.Unlock()
	if p, ok := t.items[itemID]; ok {
		p.OutputPath = path
		p.Status = StatusCompleted
		p.Progress = 1.0
		p.Encrypted = true
		p.ClientDecrypt = true
		p.DecryptionKey = key
		p.OutputExtension = ext
		p.InputFormat = inFmt
	}
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
