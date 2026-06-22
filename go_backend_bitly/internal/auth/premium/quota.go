package premium

const (
	// FreeQuotaMinutes is the monthly limit for free users (12 hours).
	FreeQuotaMinutes = 12 * 60 // 720 minutes

	// PremiumQuotaMinutes indicates unlimited quota for premium users.
	PremiumQuotaMinutes = -1 // Unlimited
)

// QuotaStatus describes the current quota state for a user.
type QuotaStatus struct {
	IsPremium        bool    `json:"is_premium"`
	TotalMinutes     int64   `json:"total_minutes"`
	UsedMinutes      float64 `json:"used_minutes"`
	RemainingMinutes float64 `json:"remaining_minutes"`
	CanDownload      bool    `json:"can_download"`
}

// CanDownloadMinutes checks whether the user can download a track of given duration.
func (q *QuotaStatus) CanDownloadMinutes(minutes float64) bool {
	if q.IsPremium {
		return true
	}
	return q.RemainingMinutes >= minutes
}
