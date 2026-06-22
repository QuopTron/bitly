package playback

import (
	"encoding/json"
	"fmt"
	"time"
)

func (ps *PlaybackState) Lock() {
	ps.mu.Lock()
}

func (ps *PlaybackState) Unlock() {
	ps.mu.Unlock()
}

func (ps *PlaybackState) RLock() {
	ps.mu.RLock()
}

func (ps *PlaybackState) RUnlock() {
	ps.mu.RUnlock()
}

func GetStateJSON() string {
	ps := Get()
	ps.mu.RLock()
	defer ps.mu.RUnlock()

	b, err := json.Marshal(ps)
	if err != nil {
		return fmt.Sprintf(`{"error":"%s"}`, err.Error())
	}
	return string(b)
}

func GetHistoryJSON(limit int) string {
	ps := Get()
	ps.mu.RLock()
	defer ps.mu.RUnlock()

	if limit <= 0 || limit > len(ps.History) {
		limit = len(ps.History)
	}
	reversed := make([]PlaybackTrack, limit)
	for i := 0; i < limit; i++ {
		reversed[i] = ps.History[len(ps.History)-1-i]
	}

	b, err := json.Marshal(map[string]interface{}{
		"history":  reversed,
		"total":    len(ps.History),
		"returned": limit,
	})
	if err != nil {
		return fmt.Sprintf(`{"error":"%s"}`, err.Error())
	}
	return string(b)
}

func GetQueueJSON() string {
	ps := Get()
	ps.mu.RLock()
	defer ps.mu.RUnlock()

	b, err := json.Marshal(map[string]interface{}{
		"queue":       ps.Queue,
		"queue_index": ps.QueueIndex,
		"current":     ps.CurrentTrack,
	})
	if err != nil {
		return fmt.Sprintf(`{"error":"%s"}`, err.Error())
	}
	return string(b)
}

func SetPosition(positionMs int64) {
	ps := Get()
	ps.mu.Lock()
	defer ps.mu.Unlock()
	ps.Position = positionMs
	ps.Timestamp = time.Now().UnixMilli()
}
