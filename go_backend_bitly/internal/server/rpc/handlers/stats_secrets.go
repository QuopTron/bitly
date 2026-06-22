package handlers

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/zarz/bitly/go_backend_bitly/internal/server/rpc"
	"github.com/zarz/bitly/go_backend_bitly/internal/storage/database"
)

// RegisterStatsHandlers registers stats and analytics RPC methods.
func RegisterStatsHandlers(reg *rpc.Registry) {
	reg.Register("logPlay", func(params map[string]interface{}) (interface{}, error) {
		trackID := rpc.Sp(params, "track_id")
		trackName := rpc.Sp(params, "track_name")
		artistName := rpc.Sp(params, "artist_name")
		albumName := rpc.Sp(params, "album_name")
		playedAt := rpc.Sp(params, "played_at")
		durationMs := rpc.Sn(params, "duration_ms")
		percentage := rpc.Sn(params, "percentage")

		db, err := database.Get()
		if err != nil {
			return nil, err
		}
		if playedAt == "" {
			playedAt = time.Now().UTC().Format(time.RFC3339)
		}
		_, err = db.Exec(`INSERT INTO play_history (track_id, track_name, artist_name, album_name, played_at, duration_ms, percentage)
			VALUES (?, ?, ?, ?, ?, ?, ?)`,
			trackID, trackName, artistName, albumName, playedAt, durationMs, percentage)
		return "ok", err
	})

	reg.Register("getRecentPlays", func(params map[string]interface{}) (interface{}, error) {
		limit := rpc.Sn(params, "limit")
		if limit <= 0 {
			limit = 20
		}
		db, err := database.Get()
		if err != nil {
			return "[]", nil
		}
		rows, err := db.Query("SELECT * FROM play_history ORDER BY played_at DESC LIMIT ?", limit)
		if err != nil {
			return "[]", nil
		}
		defer rows.Close()
		return rowsToJSON(rows), nil
	})

	reg.Register("clearPlayHistory", func(params map[string]interface{}) (interface{}, error) {
		db, err := database.Get()
		if err != nil {
			return nil, err
		}
		_, err = db.Exec("DELETE FROM play_history")
		return "ok", err
	})

	reg.Register("incrementPlayCount", func(params map[string]interface{}) (interface{}, error) {
		itemID := rpc.Sp(params, "request")
		itemType := rpc.Sp(params, "type")
		db, err := database.Get()
		if err != nil {
			return nil, err
		}
		_, err = db.Exec(`INSERT INTO play_aggregates (item_id, type, play_count, last_played_at)
			VALUES (?, ?, 1, ?)
			ON CONFLICT(item_id) DO UPDATE SET play_count = play_count + 1, last_played_at = excluded.last_played_at`,
			itemID, itemType, time.Now().UTC().Format(time.RFC3339))
		return "ok", err
	})

	reg.Register("getPlayAggregates", func(params map[string]interface{}) (interface{}, error) {
		itemType := rpc.Sp(params, "type")
		db, err := database.Get()
		if err != nil {
			return "[]", nil
		}
		if itemType != "" {
			rows, err := db.Query("SELECT * FROM play_aggregates WHERE type = ? ORDER BY play_count DESC", itemType)
			if err != nil {
				return "[]", nil
			}
			defer rows.Close()
			return rowsToJSON(rows), nil
		}
		rows, err := db.Query("SELECT * FROM play_aggregates ORDER BY play_count DESC")
		if err != nil {
			return "[]", nil
		}
		defer rows.Close()
		return rowsToJSON(rows), nil
	})

	reg.Register("getTotalStats", func(params map[string]interface{}) (interface{}, error) {
		db, err := database.Get()
		if err != nil {
			return "{\"totalPlays\":0,\"uniqueTracks\":0,\"uniqueAlbums\":0,\"uniqueArtists\":0,\"totalDays\":0}", nil
		}

		var totalPlays, tracks, albums, artists int
		db.QueryRow("SELECT COALESCE(SUM(play_count),0) FROM play_aggregates WHERE type = 'track'").Scan(&totalPlays)
		db.QueryRow("SELECT COUNT(*) FROM play_aggregates WHERE type = 'track'").Scan(&tracks)
		db.QueryRow("SELECT COUNT(*) FROM play_aggregates WHERE type = 'album'").Scan(&albums)
		db.QueryRow("SELECT COUNT(*) FROM play_aggregates WHERE type = 'artist'").Scan(&artists)

		result := map[string]interface{}{
			"totalPlays":    totalPlays,
			"uniqueTracks":  tracks,
			"uniqueAlbums":  albums,
			"uniqueArtists": artists,
			"totalDays":     0,
		}
		out, _ := json.Marshal(result)
		return string(out), nil
	})

	reg.Register("getTopTracks", func(params map[string]interface{}) (interface{}, error) {
		limit := rpc.Sn(params, "limit")
		if limit <= 0 {
			limit = 20
		}
		db, err := database.Get()
		if err != nil {
			return "[]", nil
		}
		rows, err := db.Query("SELECT * FROM play_aggregates WHERE type = 'track' ORDER BY play_count DESC LIMIT ?", limit)
		if err != nil {
			return "[]", nil
		}
		defer rows.Close()
		return rowsToJSON(rows), nil
	})

	reg.Register("getTopAlbums", func(params map[string]interface{}) (interface{}, error) {
		limit := rpc.Sn(params, "limit")
		if limit <= 0 {
			limit = 20
		}
		db, err := database.Get()
		if err != nil {
			return "[]", nil
		}
		rows, err := db.Query("SELECT * FROM play_aggregates WHERE type = 'album' ORDER BY play_count DESC LIMIT ?", limit)
		if err != nil {
			return "[]", nil
		}
		defer rows.Close()
		return rowsToJSON(rows), nil
	})

	reg.Register("getTopArtists", func(params map[string]interface{}) (interface{}, error) {
		limit := rpc.Sn(params, "limit")
		if limit <= 0 {
			limit = 20
		}
		db, err := database.Get()
		if err != nil {
			return "[]", nil
		}
		rows, err := db.Query("SELECT * FROM play_aggregates WHERE type = 'artist' ORDER BY play_count DESC LIMIT ?", limit)
		if err != nil {
			return "[]", nil
		}
		defer rows.Close()
		return rowsToJSON(rows), nil
	})

	reg.Register("incrementNightPlays", func(params map[string]interface{}) (interface{}, error) {
		db, err := database.Get()
		if err != nil {
			return nil, err
		}
		_, err = db.Exec("INSERT INTO secret_counters (key, value) VALUES ('night_plays', 1) ON CONFLICT(key) DO UPDATE SET value = value + 1")
		return "ok", err
	})

	reg.Register("updateAlbumStreak", func(params map[string]interface{}) (interface{}, error) {
		streak := rpc.Sn(params, "streak")
		db, err := database.Get()
		if err != nil {
			return nil, err
		}
		var current int
		db.QueryRow("SELECT COALESCE(value,0) FROM secret_counters WHERE key = 'max_album_streak'").Scan(&current)
		if streak > current {
			_, err = db.Exec("INSERT INTO secret_counters (key, value) VALUES ('max_album_streak', ?) ON CONFLICT(key) DO UPDATE SET value = ?", streak, streak)
		}
		return "ok", err
	})

	reg.Register("clearAllStats", func(params map[string]interface{}) (interface{}, error) {
		db, err := database.Get()
		if err != nil {
			return nil, err
		}
		if _, err := db.Exec("DELETE FROM play_history"); err != nil {
			return nil, fmt.Errorf("clear play_history: %w", err)
		}
		if _, err := db.Exec("DELETE FROM play_aggregates"); err != nil {
			return nil, fmt.Errorf("clear play_aggregates: %w", err)
		}
		if _, err := db.Exec("DELETE FROM secret_counters"); err != nil {
			return nil, fmt.Errorf("clear secret_counters: %w", err)
		}
		if _, err := db.Exec("DELETE FROM secret_unlocks"); err != nil {
			return nil, fmt.Errorf("clear secret_unlocks: %w", err)
		}
		return "ok", nil
	})
}

// RegisterSecretsHandlers registers secrets-related RPC methods.
func RegisterSecretsHandlers(reg *rpc.Registry) {
	reg.Register("getSecretCounter", func(params map[string]interface{}) (interface{}, error) {
		key := rpc.Sp(params, "key")
		db, err := database.Get()
		if err != nil {
			return "0", nil
		}
		var count int
		err = db.QueryRow("SELECT COALESCE(value,0) FROM secret_counters WHERE key = ?", key).Scan(&count)
		if err != nil {
			return "0", nil
		}
		return json.Number(fmt.Sprintf("%d", count)), nil
	})

	reg.Register("isSecretUnlocked", func(params map[string]interface{}) (interface{}, error) {
		key := rpc.Sp(params, "key")
		db, err := database.Get()
		if err != nil {
			return false, nil
		}
		var count int
		db.QueryRow("SELECT COUNT(*) FROM secret_unlocks WHERE key = ?", key).Scan(&count)
		return count > 0, nil
	})

	reg.Register("unlockSecret", func(params map[string]interface{}) (interface{}, error) {
		key := rpc.Sp(params, "key")
		db, err := database.Get()
		if err != nil {
			return nil, err
		}
		_, err = db.Exec("INSERT OR IGNORE INTO secret_unlocks (key, unlocked_at) VALUES (?, ?)",
			key, time.Now().UTC().Format(time.RFC3339))
		return "ok", err
	})

	reg.Register("getUnlockedSecrets", func(params map[string]interface{}) (interface{}, error) {
		db, err := database.Get()
		if err != nil {
			return "[]", nil
		}
		rows, err := db.Query("SELECT key FROM secret_unlocks")
		if err != nil {
			return "[]", nil
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
	})
}

// rowsToJSON converts sql.Rows to a JSON string.
func rowsToJSON(rows interface {
	Columns() ([]string, error)
	Next() bool
	Scan(dest ...interface{}) error
}) string {
	cols, err := rows.Columns()
	if err != nil {
		return "[]"
	}
	var results []map[string]interface{}
	for rows.Next() {
		vals := make([]interface{}, len(cols))
		valPtrs := make([]interface{}, len(cols))
		for i := range vals {
			valPtrs[i] = &vals[i]
		}
		if err := rows.Scan(valPtrs...); err != nil {
			continue
		}
		row := make(map[string]interface{})
		for i, col := range cols {
			if vals[i] != nil {
				switch v := vals[i].(type) {
				case []byte:
					row[col] = string(v)
				default:
					row[col] = v
				}
			}
		}
		results = append(results, row)
	}
	if results == nil {
		results = []map[string]interface{}{}
	}
	out, _ := json.Marshal(results)
	return string(out)
}
