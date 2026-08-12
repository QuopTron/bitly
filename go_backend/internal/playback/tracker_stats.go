package playback

import (
	"math"
	"sort"
	"time"
)

// Stats returns playback statistics.
func (t *Tracker) Stats() map[string]interface{} {
	t.mu.RLock()
	defer t.mu.RUnlock()
	totalDuration := 0
	for _, e := range t.history {
		totalDuration += e.Duration
	}
	return map[string]interface{}{
		"totalPlays":    len(t.history),
		"uniqueTracks":  len(t.playCounts),
		"uniqueArtists": len(t.artistCount),
		"totalDuration": totalDuration,
		"queueLength":   len(t.queue),
	}
}

// GetRecommendations returns track IDs from history to recommend.
func (t *Tracker) GetRecommendations(limit int) []PlayEvent {
	t.mu.RLock()
	defer t.mu.RUnlock()
	if len(t.history) == 0 {
		return nil
	}

	type scored struct {
		event PlayEvent
		score float64
	}
	var scoredEvents []scored
	now := time.Now()
	seen := make(map[string]bool)

	for _, e := range t.history {
		if seen[e.Track.ID] {
			continue
		}
		seen[e.Track.ID] = true

		hoursAgo := now.Sub(time.Unix(e.Timestamp, 0)).Hours()
		recencyScore := math.Exp(-hoursAgo / 48.0)
		freqScore := math.Log(float64(t.playCounts[e.Track.ID]) + 1)
		score := recencyScore*0.6 + freqScore*0.4

		scoredEvents = append(scoredEvents, scored{e, score})
	}

	sort.Slice(scoredEvents, func(i, j int) bool {
		return scoredEvents[i].score > scoredEvents[j].score
	})

	if limit > len(scoredEvents) {
		limit = len(scoredEvents)
	}
	result := make([]PlayEvent, limit)
	for i := 0; i < limit; i++ {
		result[i] = scoredEvents[i].event
	}
	return result
}
