package quota

import (
	"fmt"
)

// QuotaChecker verifies quota limits before operations.
type QuotaChecker struct {
	tracker   *QuotaTracker
	calculator *DurationCalculator
}

// NewQuotaChecker creates a new quota checker.
func NewQuotaChecker(tracker *QuotaTracker) *QuotaChecker {
	return &QuotaChecker{
		tracker:    tracker,
		calculator: &DurationCalculator{},
	}
}

// CheckBeforeDownload checks whether the user can download a specific track.
func (c *QuotaChecker) CheckBeforeDownload(userID string, durationMs int64) error {
	durationMin := float64(durationMs) / 1000 / 60
	status, err := c.tracker.GetStatus(userID)
	if err != nil {
		return fmt.Errorf("quota check failed: %w", err)
	}
	if !status.CanDownloadMinutes(durationMin) {
		return ErrQuotaExceeded
	}
	return nil
}
