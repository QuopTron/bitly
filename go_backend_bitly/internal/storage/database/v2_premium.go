package database

import (
	"encoding/json"
	"time"
)

// ============================================================
// V2: User Premium & Tier
// ============================================================

// GetUserPremiumV2 returns premium status as JSON.
func GetUserPremiumV2() (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	var id, tier, createdAt, updatedAt string
	var premiumUntil, dailyPlayLimit int64
	err = db.QueryRow(`SELECT id, tier, premium_until, daily_play_limit, created_at, updated_at
		FROM user_premium WHERE id = 'default'`).Scan(&id, &tier, &premiumUntil, &dailyPlayLimit, &createdAt, &updatedAt)
	if err != nil {
		return `{"tier":"free","premiumUntil":0,"dailyPlayLimit":50,"activo":false}`, nil
	}
	activo := tier != "free" && (tier == "lifetime" || premiumUntil > time.Now().UnixMilli())
	result := map[string]interface{}{
		"id":             id,
		"tier":           tier,
		"premiumUntil":   premiumUntil,
		"dailyPlayLimit": dailyPlayLimit,
		"activo":         activo,
		"createdAt":      createdAt,
		"updatedAt":      updatedAt,
	}
	out, _ := json.Marshal(result)
	return string(out), nil
}

// SetUserPremiumV2 sets premium tier and expiry.
func SetUserPremiumV2(tier string, premiumUntil int64) error {
	db, err := Get()
	if err != nil {
		return err
	}
	now := time.Now().UTC().Format(time.RFC3339)
	dailyLimit := int64(50)
	if tier != "free" {
		dailyLimit = int64(200)
	}
	if tier == "lifetime" {
		dailyLimit = int64(999999)
	}
	_, err = db.Exec(`INSERT INTO user_premium (id, tier, premium_until, daily_play_limit, created_at, updated_at)
		VALUES ('default', ?, ?, ?, ?, ?)
		ON CONFLICT(id) DO UPDATE SET
			tier = excluded.tier,
			premium_until = excluded.premium_until,
			daily_play_limit = excluded.daily_play_limit,
			updated_at = excluded.updated_at`,
		tier, premiumUntil, dailyLimit, now, now)
	return err
}
