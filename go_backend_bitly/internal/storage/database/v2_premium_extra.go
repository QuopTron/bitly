package database

import (
	"encoding/json"
	"time"
)

// GetListeningLevelV2 returns the listening level based on play counts.
func GetListeningLevelV2() (string, error) {
	db, err := Get()
	if err != nil {
		return "", nil
	}
	var totalPlays int64
	db.QueryRow("SELECT COALESCE(SUM(play_count),0) FROM play_aggregates WHERE type = 'track'").Scan(&totalPlays)

	level := "free"
	var dailyLimit int64 = 50

	if totalPlays >= 10000 {
		level = "legend"
		dailyLimit = 999999
	} else if totalPlays >= 5000 {
		level = "gold"
		dailyLimit = 300
	} else if totalPlays >= 1000 {
		level = "silver"
		dailyLimit = 200
	} else if totalPlays >= 100 {
		level = "bronze"
		dailyLimit = 100
	}

	var rowsThisPeriod int64
	today := time.Now().UTC().Format("2006-01-02")
	db.QueryRow("SELECT COALESCE(play_count,0) FROM user_daily_plays WHERE date = ?", today).Scan(&rowsThisPeriod)

	var premiumTier string
	var premiumUntil int64
	if err := db.QueryRow("SELECT tier, premium_until FROM user_premium WHERE id = 'default'").Scan(&premiumTier, &premiumUntil); err == nil {
		if premiumTier != "free" && (premiumTier == "lifetime" || premiumUntil > time.Now().UnixMilli()) {
			if premiumTier == "lifetime" {
				level = "legend"
				dailyLimit = 999999
			} else {
				dailyLimit = 500
				if totalPlays >= 5000 {
					level = "legend"
					dailyLimit = 999999
				} else if totalPlays >= 1000 {
					level = "gold"
				} else {
					level = "premium"
				}
			}
		}
	}

	result := map[string]interface{}{
		"level":          level,
		"totalPlays":     totalPlays,
		"dailyLimit":     dailyLimit,
		"playsToday":     rowsThisPeriod,
		"playsRemaining": dailyLimit - rowsThisPeriod,
	}
	if rowsThisPeriod >= dailyLimit {
		result["blocked"] = true
	} else {
		result["blocked"] = false
	}
	out, _ := json.Marshal(result)
	return string(out), nil
}

// LogPlayV2 records a play with aggregates and daily count.
func LogPlayV2(trackID, trackName, artistName, albumName string, durationMs, percentage int) error {
	db, err := Get()
	if err != nil {
		return err
	}
	now := time.Now().UTC().Format(time.RFC3339)

	_, err = db.Exec(`INSERT INTO play_history (track_id, track_name, artist_name, album_name, played_at, duration_ms, percentage)
		VALUES (?, ?, ?, ?, ?, ?, ?)`, trackID, trackName, artistName, albumName, now, durationMs, percentage)
	if err != nil {
		return err
	}

	db.Exec(`INSERT INTO play_aggregates (item_id, type, play_count, last_played_at)
		VALUES (?, 'track', 1, ?)
		ON CONFLICT(item_id) DO UPDATE SET play_count = play_count + 1, last_played_at = excluded.last_played_at`,
		trackID, now)

	today := time.Now().UTC().Format("2006-01-02")
	db.Exec(`INSERT INTO user_daily_plays (date, play_count) VALUES (?, 1)
		ON CONFLICT(date) DO UPDATE SET play_count = play_count + 1`, today)

	return nil
}
