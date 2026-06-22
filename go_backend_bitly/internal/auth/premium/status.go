package premium

import (
	"fmt"
	"time"
)

// GetStatus returns the current premium status for a user.
// In a real implementation this queries the database for usage this month
// and checks whether the user has an active premium subscription.
func GetStatus(userID string, usedMinutes float64, isPremium bool) (*QuotaStatus, error) {
	totalMinutes := int64(FreeQuotaMinutes)
	if isPremium {
		totalMinutes = PremiumQuotaMinutes
	}

	remaining := float64(FreeQuotaMinutes) - usedMinutes
	if remaining < 0 {
		remaining = 0
	}
	if isPremium {
		remaining = -1 // unlimited
	}

	return &QuotaStatus{
		IsPremium:        isPremium,
		TotalMinutes:     totalMinutes,
		UsedMinutes:      usedMinutes,
		RemainingMinutes: remaining,
		CanDownload:      isPremium || remaining > 0,
	}, nil
}

// VerifyPremium checks if a premium subscription is still valid.
// premiumUntil is in milliseconds; 0 means no expiration.
func VerifyPremium(isPremium bool, premiumUntil int64) error {
	if isPremium && premiumUntil == 0 {
		return nil
	}
	if premiumUntil > 0 {
		now := time.Now().UnixMilli()
		if now > premiumUntil {
			return fmt.Errorf("premium period expired")
		}
		return nil
	}
	return fmt.Errorf("premium required")
}
