package quota

import "github.com/zarz/bitly/go_backend_bitly/internal/domain/track"

// DurationCalculator computes track/album/playlist durations for quota checks.
type DurationCalculator struct{}

// CalculateTrackMinutes returns the duration of a single track in minutes.
func (c *DurationCalculator) CalculateTrackMinutes(t track.Track) float64 {
	return float64(t.DurationMs) / 1000 / 60
}

// CalculateTotalMinutes returns the total duration of multiple tracks in minutes.
func (c *DurationCalculator) CalculateTotalMinutes(tracks []track.Track) float64 {
	var totalMs int64
	for _, t := range tracks {
		totalMs += t.DurationMs
	}
	return float64(totalMs) / 1000 / 60
}
