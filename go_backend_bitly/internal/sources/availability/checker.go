package availability

import (
	"time"
)

// AvailabilityResult describes a provider's availability for a track.
type AvailabilityResult struct {
	Provider  string `json:"provider"`
	TrackID   string `json:"track_id"`
	Available bool   `json:"available"`
	Quality   string `json:"quality,omitempty"`
	URL       string `json:"url,omitempty"`
}

// Checker checks track availability across providers.
type Checker struct {
	client   *Client
	resolver *LinkResolver
}

// NewChecker creates an availability checker.
func NewChecker() *Checker {
	return &Checker{
		client:   NewClient(),
		resolver: GetLinkResolver(),
	}
}

// CheckTrack checks availability for a single track by querying SongLink.
func (c *Checker) CheckTrack(spotifyID, isrc string) ([]AvailabilityResult, error) {
	if spotifyID == "" && isrc == "" {
		return []AvailabilityResult{}, nil
	}

	var results []AvailabilityResult

	if spotifyID != "" {
		avail, err := c.client.CheckAvailabilityFromDeezer(spotifyID)
		if err == nil && avail != nil {
			if avail.Deezer && avail.DeezerURL != "" {
				results = append(results, AvailabilityResult{
					Provider:  "deezer", TrackID: spotifyID, Available: true, Quality: "lossless",
				})
			}
			if avail.Tidal && avail.TidalURL != "" {
				results = append(results, AvailabilityResult{
					Provider: "tidal", TrackID: spotifyID, Available: true, Quality: "lossless",
				})
			}
			if avail.Qobuz && avail.QobuzURL != "" {
				results = append(results, AvailabilityResult{
					Provider: "qobuz", TrackID: spotifyID, Available: true, Quality: "lossless",
				})
			}
		}
	}

	if isrc != "" && len(results) == 0 && c.resolver != nil {
		resolved, err := c.resolver.ResolveByISRC(isrc)
		if err == nil && resolved != nil {
			if resolved.DeezerURL != "" {
				results = append(results, AvailabilityResult{Provider: "deezer", TrackID: isrc, Available: true, Quality: "lossless", URL: resolved.DeezerURL})
			}
			if resolved.TidalURL != "" {
				results = append(results, AvailabilityResult{Provider: "tidal", TrackID: isrc, Available: true, Quality: "lossless", URL: resolved.TidalURL})
			}
			if resolved.QobuzURL != "" {
				results = append(results, AvailabilityResult{Provider: "qobuz", TrackID: isrc, Available: true, Quality: "lossless", URL: resolved.QobuzURL})
			}
		}
	}

	return results, nil
}

// CheckTrackAvailability implements the core.AvailabilityChecker interface.
func (c *Checker) CheckTrackAvailability(spotifyID, isrc string) (interface{}, error) {
	results, err := c.CheckTrack(spotifyID, isrc)
	if err != nil {
		return nil, err
	}
	resultMap := map[string]interface{}{
		"timestamp": time.Now().Unix(),
	}
	for _, r := range results {
		resultMap[r.Provider] = r.Available
		resultMap[r.Provider+"_url"] = r.URL
	}
	return resultMap, nil
}
