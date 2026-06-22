package quota

import "time"

// ResetMonthlyQuota optionally cleans up old quota records.
// Quotas are calculated dynamically per month, so explicit reset is not required.
func ResetMonthlyQuota() error {
	return nil
}

// GetNextResetDate returns the start of the next month.
func GetNextResetDate() time.Time {
	now := time.Now()
	nextMonth := now.AddDate(0, 1, 0)
	return time.Date(nextMonth.Year(), nextMonth.Month(), 1, 0, 0, 0, 0, now.Location())
}
