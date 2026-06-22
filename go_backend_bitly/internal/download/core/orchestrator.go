package core

import (
	"context"
	"fmt"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/domain/track"
	"github.com/zarz/bitly/go_backend_bitly/internal/quota"
	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
)

// SingleDownloadRequest describes a single download request.
type SingleDownloadRequest struct {
	UserID  string
	Track   track.Track
	Quality string
	Type    string
}

// DownloadOrchestrator manages the entire download process.
type DownloadOrchestrator struct {
	quotaTracker *quota.QuotaTracker
	queue        *DownloadQueue
	selector     *core.SourceSelector
	fallback     *core.FallbackManager
}

// NewDownloadOrchestrator creates a new orchestrator.
func NewDownloadOrchestrator(
	qt *quota.QuotaTracker,
	queue *DownloadQueue,
	selector *core.SourceSelector,
	fallback *core.FallbackManager,
) *DownloadOrchestrator {
	return &DownloadOrchestrator{
		quotaTracker: qt,
		queue:        queue,
		selector:     selector,
		fallback:     fallback,
	}
}

// DownloadSingle downloads a single track.
func (o *DownloadOrchestrator) DownloadSingle(ctx context.Context, req SingleDownloadRequest) error {
	durationMin := float64(req.Track.DurationMs) / 1000 / 60

	// 1. Reserve quota
	if err := o.quotaTracker.ReserveDownload(req.UserID, req.Track.ID, durationMin); err != nil {
		return fmt.Errorf("quota: %w", err)
	}

	// 2. Select source
	source, err := o.selector.SelectBestSource(req.Track.ID, req.Track.ISRC, req.Quality)
	if err != nil {
		o.quotaTracker.ReleaseDownload(req.UserID, req.Track.ID)
		return fmt.Errorf("select source: %w", err)
	}

	// 3. Enqueue job
	job := &DownloadJob{
		ID:        req.Track.ID,
		UserID:    req.UserID,
		TrackID:   req.Track.ID,
		TrackName: req.Track.Title,
		Quality:   source.Quality,
		Source:    source.Provider,
		Type:      req.Type,
		Status:    "pending",
		CreatedAt: time.Now(),
		MaxRetries: 3,
	}
	o.queue.Enqueue(job)

	return nil
}


