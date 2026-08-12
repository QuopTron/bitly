// Package rescue implements multi-provider rescue by ISRC.
// When a track can't be found on one provider, it tries all others
// in priority order and returns the best match.
package rescue

import (
	"fmt"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// Priority defines the order in which providers are tried.
var priority = []string{
	"deezer", "qobuz", "tidal", "spotify",
	"apple", "soundcloud", "youtube", "musicbrainz",
}

// Result holds the rescue outcome.
type Result struct {
	Found      bool                `json:"found"`
	Provider   string              `json:"provider"`
	Track      *provider.TrackResult `json:"track,omitempty"`
	StreamURL  string              `json:"streamUrl,omitempty"`
	Error      string              `json:"error,omitempty"`
	Attempted  []string            `json:"attempted"`
}

// Rescuer orchestrates multi-provider rescue attempts.
type Rescuer struct {
	registry *provider.Registry
}

// New creates a rescuer with the provider registry.
func New(reg *provider.Registry) *Rescuer {
	return &Rescuer{registry: reg}
}

// RescueByISRC tries all providers to find and return a track by ISRC.
// Returns the best result with stream URL if possible.
func (r *Rescuer) RescueByISRC(isrc, trackName, artistName, quality string) *Result {
	result := &Result{Attempted: []string{}}

	for _, name := range priority {
		p := r.registry.Get(name)
		if p == nil {
			continue
		}
		result.Attempted = append(result.Attempted, name)

		// Try ISRC lookup first
		track, err := p.GetTrackByISRC(isrc)
		if err != nil {
			// Try search by name if ISRC fails
			if trackName != "" {
				searchResults, searchErr := p.SearchTracks(trackName+" "+artistName, 8)
				if searchErr == nil && len(searchResults) > 0 {
					if best := provider.BestOriginal(trackName, artistName, searchResults); best != nil {
						track = best
						err = nil
					}
				}
			}
			if err != nil {
				continue
			}
		}
		if track == nil {
			continue
		}

		result.Found = true
		result.Provider = name
		result.Track = track

		// Try to get stream URL
		if quality == "" {
			quality = "lossless"
		}
		streamURL, err := p.GetStreamURL(track.ID, quality)
		if err == nil && streamURL != "" {
			result.StreamURL = streamURL
		}

		return result
	}

	result.Error = fmt.Sprintf("no provider found track for ISRC %s", isrc)
	return result
}

// RescueBatch rescues multiple tracks in parallel.
func (r *Rescuer) RescueBatch(tracks []RescueRequest) []*Result {
	results := make([]*Result, len(tracks))
	type job struct {
		index int
		req   RescueRequest
	}
	jobs := make(chan job, len(tracks))
	done := make(chan struct{}, 5) // 5 concurrent rescues

	// Worker pool
	worker := func() {
		for j := range jobs {
			results[j.index] = r.RescueByISRC(j.req.ISRC, j.req.TrackName, j.req.ArtistName, j.req.Quality)
		}
		done <- struct{}{}
	}

	// Start workers
	numWorkers := 5
	if len(tracks) < numWorkers {
		numWorkers = len(tracks)
	}
	for range numWorkers {
		go worker()
	}

	// Send jobs
	for i, req := range tracks {
		jobs <- job{index: i, req: req}
	}
	close(jobs)

	// Wait for all workers
	for range numWorkers {
		<-done
	}

	return results
}

// RescueRequest represents a single rescue job.
type RescueRequest struct {
	ISRC        string `json:"isrc"`
	TrackName   string `json:"trackName"`
	ArtistName  string `json:"artistName"`
	Quality     string `json:"quality"`
}
