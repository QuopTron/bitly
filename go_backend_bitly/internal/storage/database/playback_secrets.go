package database

import (
	"encoding/json"
	"time"
)

func GetSecretCounter(key string) (int, error) {
	db, err := Get()
	if err != nil {
		return 0, err
	}
	var count int
	err = db.QueryRow("SELECT COALESCE(value,0) FROM secret_counters WHERE key = ?", key).Scan(&count)
	return count, err
}

func IncrementNightPlays() error {
	db, err := Get()
	if err != nil {
		return err
	}
	_, err = db.Exec("INSERT INTO secret_counters (key, value) VALUES ('night_plays', 1) ON CONFLICT(key) DO UPDATE SET value = value + 1")
	return err
}

func UpdateAlbumStreak(streak int) error {
	db, err := Get()
	if err != nil {
		return err
	}
	var current int
	db.QueryRow("SELECT COALESCE(value,0) FROM secret_counters WHERE key = 'max_album_streak'").Scan(&current)
	if streak > current {
		_, err = db.Exec("INSERT INTO secret_counters (key, value) VALUES ('max_album_streak', ?) ON CONFLICT(key) DO UPDATE SET value = ?", streak, streak)
	}
	return err
}

func IsSecretUnlocked(key string) (bool, error) {
	db, err := Get()
	if err != nil {
		return false, err
	}
	var count int
	db.QueryRow("SELECT COUNT(*) FROM secret_unlocks WHERE key = ?", key).Scan(&count)
	return count > 0, nil
}

func UnlockSecret(key string) error {
	db, err := Get()
	if err != nil {
		return err
	}
	_, err = db.Exec("INSERT OR IGNORE INTO secret_unlocks (key, unlocked_at) VALUES (?, ?)",
		key, time.Now().UTC().Format(time.RFC3339))
	return err
}

func GetUnlockedSecrets() (string, error) {
	db, err := Get()
	if err != nil {
		return "", err
	}
	rows, err := db.Query("SELECT key FROM secret_unlocks")
	if err != nil {
		return "", err
	}
	defer rows.Close()

	var keys []string
	for rows.Next() {
		var k string
		if err := rows.Scan(&k); err == nil {
			keys = append(keys, k)
		}
	}
	if keys == nil {
		keys = []string{}
	}
	out, _ := json.Marshal(keys)
	return string(out), nil
}
