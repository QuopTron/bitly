// Package recommend provides track and artist recommendations
// using provider data (similar tracks, related artists).
package recommend

import (
	"fmt"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// Engine provides recommendation services.
type Engine struct {
	registry *provider.Registry
}

// New creates a recommendation engine.
func New(reg *provider.Registry) *Engine {
	return &Engine{registry: reg}
}

// SimilarTracks finds tracks similar to a given track.
// Uses the provider's search with the track's artist name.
func (e *Engine) SimilarTracks(trackTitle, artistName string, limit int) ([]provider.TrackResult, error) {
	if limit < 1 {
		limit = 10
	}

	var all []provider.TrackResult
	seen := make(map[string]bool)

	// Search by genre/style keywords
	queries := []string{
		artistName + " " + trackTitle,
		"similar to " + trackTitle,
	}

	for _, query := range queries {
		for _, p := range e.registry.All() {
			results, err := p.SearchTracks(query, limit)
			if err != nil || results == nil {
				continue
			}
			for _, t := range results {
				if seen[t.ID] {
					continue
				}
				// Don't recommend the exact same track
				if t.Title == trackTitle && t.Artist == artistName {
					continue
				}
				seen[t.ID] = true
				all = append(all, t)
			}
			if len(all) >= limit {
				break
			}
		}
		if len(all) >= limit {
			break
		}
	}

	if len(all) > limit {
		all = all[:limit]
	}
	return all, nil
}

// SimilarArtists finds artists similar to a given artist.
func (e *Engine) SimilarArtists(artistName string, limit int) ([]provider.ArtistResult, error) {
	if limit < 1 {
		limit = 10
	}

	var all []provider.ArtistResult
	seen := make(map[string]bool)

	for _, p := range e.registry.All() {
		results, err := p.SearchArtists("similar to "+artistName, limit)
		if err != nil || results == nil {
			continue
		}
		for _, a := range results {
			if seen[a.ID] {
				continue
			}
			if a.Name == artistName {
				continue
			}
			seen[a.ID] = true
			all = append(all, a)
		}
		if len(all) >= limit {
			break
		}
	}

	if len(all) > limit {
		all = all[:limit]
	}
	return all, nil
}

// GetTrack returns metadata for a track ID from any provider.
func GetTrack(reg *provider.Registry, trackID string) (*provider.TrackResult, error) {
	for _, p := range reg.All() {
		track, err := p.GetTrack(trackID)
		if err == nil && track != nil {
			return track, nil
		}
	}
	return nil, fmt.Errorf("track %s not found on any provider", trackID)
}
