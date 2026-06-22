package quota

import (
	"database/sql"
	"fmt"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/auth/premium"
)

// QuotaStorage persists quota usage to the database.
type QuotaStorage struct {
	db *sql.DB
}

// NewQuotaStorage creates a new storage backend.
func NewQuotaStorage(db *sql.DB) *QuotaStorage {
	return &QuotaStorage{db: db}
}

// GetUsedMinutes returns the total minutes used by a user in the current month.
func (s *QuotaStorage) GetUsedMinutes(userID string, month time.Time) (float64, error) {
	monthStr := month.Format("2006-01")
	var total sql.NullFloat64
	err := s.db.QueryRow(`
		SELECT COALESCE(SUM(duration_minutes), 0)
		FROM quota_usage
		WHERE user_id = ? AND strftime('%Y-%m', downloaded_at) = ?
	`, userID, monthStr).Scan(&total)
	if err != nil {
		return 0, fmt.Errorf("get used minutes: %w", err)
	}
	return total.Float64, nil
}

// ReserveMinutes creates a temporary quota reservation.
func (s *QuotaStorage) ReserveMinutes(userID, trackID string, minutes float64) error {
	_, err := s.db.Exec(`
		INSERT INTO quota_usage (user_id, track_id, duration_minutes, status)
		VALUES (?, ?, ?, 'reserved')
	`, userID, trackID, minutes)
	return err
}

// ConfirmMinutes finalizes a reservation and records actual usage.
func (s *QuotaStorage) ConfirmMinutes(userID, trackID string, minutes float64) error {
	_, err := s.db.Exec(`
		UPDATE quota_usage SET status = 'completed', duration_minutes = ?
		WHERE user_id = ? AND track_id = ? AND status = 'reserved'
	`, minutes, userID, trackID)
	return err
}

// ReleaseReservation removes a pending reservation.
func (s *QuotaStorage) ReleaseReservation(userID, trackID string) error {
	_, err := s.db.Exec(`
		DELETE FROM quota_usage
		WHERE user_id = ? AND track_id = ? AND status = 'reserved'
	`, userID, trackID)
	return err
}

// GetStatus returns the full quota status for a user.
func (s *QuotaStorage) GetStatus(userID string) (*premium.QuotaStatus, error) {
	now := time.Now()
	used, err := s.GetUsedMinutes(userID, now)
	if err != nil {
		return nil, err
	}

	var dbPremium bool
	err = s.db.QueryRow(`SELECT EXISTS(SELECT 1 FROM premium_users WHERE user_id = ? AND expires_at > datetime('now'))`, userID).Scan(&dbPremium)
	if err != nil {
		dbPremium = false
	}

	remaining := float64(0)
	if !dbPremium {
		remaining = float64(720) - used
		if remaining < 0 {
			remaining = 0
		}
	}

	return &premium.QuotaStatus{
		IsPremium:        dbPremium,
		TotalMinutes:     720,
		UsedMinutes:      used,
		RemainingMinutes: remaining,
		CanDownload:      dbPremium || remaining > 0,
	}, nil
}
