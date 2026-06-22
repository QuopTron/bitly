package quota

import (
	"github.com/zarz/bitly/go_backend_bitly/internal/auth/premium"
)

// QuotaTracker manages download quota reservations and confirmations.
type QuotaTracker struct {
	storage *QuotaStorage
}

// NewQuotaTracker creates a new tracker with the given storage backend.
func NewQuotaTracker(storage *QuotaStorage) *QuotaTracker {
	return &QuotaTracker{
		storage: storage,
	}
}

// ReserveDownload tentatively reserves quota for a download.
func (t *QuotaTracker) ReserveDownload(userID, trackID string, durationMin float64) error {
	status, err := t.storage.GetStatus(userID)
	if err != nil {
		return err
	}
	if !status.CanDownloadMinutes(durationMin) {
		return ErrQuotaExceeded
	}
	return t.storage.ReserveMinutes(userID, trackID, durationMin)
}

// ConfirmDownload confirms a previously reserved download and deducts actual usage.
func (t *QuotaTracker) ConfirmDownload(userID, trackID string, actualDurationMin float64) error {
	if err := t.storage.ReleaseReservation(userID, trackID); err != nil {
		return err
	}
	return t.storage.ConfirmMinutes(userID, trackID, actualDurationMin)
}

// ReleaseDownload cancels a reservation without deducting quota.
func (t *QuotaTracker) ReleaseDownload(userID, trackID string) error {
	return t.storage.ReleaseReservation(userID, trackID)
}

// GetStatus returns the current quota status for a user.
func (t *QuotaTracker) GetStatus(userID string) (*premium.QuotaStatus, error) {
	return t.storage.GetStatus(userID)
}

var (
	// ErrQuotaExceeded is returned when the user has insufficient quota.
	ErrQuotaExceeded = &QuotaError{"quota exceeded"}
	// ErrReservationNotFound is returned when releasing a non-existent reservation.
	ErrReservationNotFound = &QuotaError{"reservation not found"}
)

// QuotaError is a domain error for quota operations.
type QuotaError struct{ msg string }

func (e *QuotaError) Error() string { return e.msg }
