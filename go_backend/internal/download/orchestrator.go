package download

import (
	"sync"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// Request represents a download request from Flutter.
type Request struct {
	ItemID    string `json:"itemId"`
	Title     string `json:"title"`
	Artist    string `json:"artist"`
	ISRC      string `json:"isrc"`
	Provider  string `json:"provider"`
	TrackID   string `json:"trackId"`
	Quality   string `json:"quality"`
	OutputDir string `json:"outputDir"`
}

// Result holds the outcome of a download.
type Result struct {
	ItemID    string `json:"itemId"`
	Success   bool   `json:"success"`
	Provider  string `json:"provider,omitempty"`
	StreamURL string `json:"streamUrl,omitempty"`
	FilePath  string `json:"filePath,omitempty"`
	Error     string `json:"error,omitempty"`
}

// Orchestrator manages downloads with provider fallback.
type Orchestrator struct {
	providers      *provider.Registry
	tracker        *Tracker
	mu             sync.Mutex
	active         map[string]bool
	fallbackOrder  []string
}

// NewOrchestrator creates a download orchestrator with fallback chain.
func NewOrchestrator(reg *provider.Registry) *Orchestrator {
	return &Orchestrator{
		providers: reg,
		tracker:   NewTracker(),
		active:    make(map[string]bool),
		fallbackOrder: []string{
			"deezer", "qobuz", "tidal", "apple",
			"soundcloud", "youtube",
		},
	}
}

// Download executes a single download with provider fallback.
func (o *Orchestrator) Download(req Request) *Result {
	o.mu.Lock()
	if o.active[req.ItemID] {
		o.mu.Unlock()
		return &Result{ItemID: req.ItemID, Success: false, Error: "already downloading"}
	}
	o.active[req.ItemID] = true
	o.mu.Unlock()

	defer func() {
		o.mu.Lock()
		delete(o.active, req.ItemID)
		o.mu.Unlock()
	}()

	o.tracker.Add(req.ItemID, req.Title, req.Provider)

	// Determine which providers to try
	providersToTry := o.fallbackOrder
	if req.Provider != "" {
		// Try requested provider first, then fallback
		providersToTry = append([]string{req.Provider}, o.fallbackOrder...)
	}

	for _, name := range providersToTry {
		if name == req.Provider && req.Provider == "" {
			continue
		}
		p := o.providers.Get(name)
		if p == nil {
			continue
		}

		o.tracker.Update(req.ItemID, StatusDownloading, 0.3)
		trackID := req.TrackID

		// Resolve by ISRC if no track ID
		if trackID == "" && req.ISRC != "" {
			track, err := p.GetTrackByISRC(req.ISRC)
			if err != nil {
				continue
			}
			if track != nil {
				trackID = track.ID
				req.Title = track.Title
				req.Artist = track.Artist
			}
		}

		if trackID == "" {
			continue
		}

		o.tracker.Update(req.ItemID, StatusDownloading, 0.6)
		streamURL, err := p.GetStreamURL(trackID, req.Quality)
		if err != nil {
			continue
		}

		o.tracker.SetOutputPath(req.ItemID, streamURL)
		o.tracker.Update(req.ItemID, StatusCompleted, 1.0)
		return &Result{
			ItemID:    req.ItemID,
			Success:   true,
			Provider:  name,
			StreamURL: streamURL,
		}
	}

	o.tracker.SetError(req.ItemID, "all providers failed")
	return &Result{
		ItemID:  req.ItemID,
		Success: false,
		Error:   "all providers failed for this track",
	}
}

// DownloadBatch executes multiple downloads in parallel.
func (o *Orchestrator) DownloadBatch(requests []Request) []*Result {
	results := make([]*Result, len(requests))
	var wg sync.WaitGroup
	for i, req := range requests {
		wg.Add(1)
		go func(idx int, r Request) {
			defer wg.Done()
			results[idx] = o.Download(r)
		}(i, req)
	}
	wg.Wait()
	return results
}

// Progress returns the tracker.
func (o *Orchestrator) Progress() *Tracker { return o.tracker }

// SetFallbackOrder overrides the default provider fallback chain.
func (o *Orchestrator) SetFallbackOrder(order []string) {
	o.fallbackOrder = order
}
