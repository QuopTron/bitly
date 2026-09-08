package gobackend

import "encoding/json"

// GetPlaybackStats returns playback statistics.
func GetPlaybackStats() string {
	if playbackTracker == nil {
		return `{}`
	}
	data, _ := json.Marshal(playbackTracker.Stats())
	return string(data)
}

// GetPlayCount returns how many times a specific track has been played.
func GetPlayCount(trackID string) string {
	if playbackTracker == nil {
		return `{"count":0}`
	}
	data, _ := json.Marshal(map[string]interface{}{"count": playbackTracker.PlayCount(trackID)})
	return string(data)
}

// GetRecommendationsFromHistory returns recommended tracks based on listening history.
func GetRecommendationsFromHistory(limit int) string {
	if playbackTracker == nil {
		return `[]`
	}
	recs := playbackTracker.GetRecommendations(limit)
	data, _ := json.Marshal(recs)
	return string(data)
}

// GetTopTracks returns the most-played tracks with their play counts.
func GetTopTracks(limit int) string {
	if playbackTracker == nil {
		return `[]`
	}
	data, _ := json.Marshal(playbackTracker.TopTracksWithCounts(limit))
	return string(data)
}
