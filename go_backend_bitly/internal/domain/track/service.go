package track

import (
	"fmt"
	"strings"
)

// Service provides business operations for tracks.
type Service struct {
	repo *Repository
}

// NewService creates a new track service.
func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

// GetOrCreate finds an existing track by ISRC or title+artist, or creates a new one.
func (s *Service) GetOrCreate(t Track) (*Track, error) {
	if t.ISRC != "" {
		existing, err := s.repo.GetByISRC(t.ISRC)
		if err == nil && existing != nil {
			return existing, nil
		}
	}

	t.NormalizedTitle = normalizeTitle(t.Title)
	if t.ID == "" {
		t.ID = generateTrackID(t)
	}

	if err := s.repo.Create(&t); err != nil {
		return nil, fmt.Errorf("create track: %w", err)
	}
	return &t, nil
}

// GetBestSource returns the best available source for a track based on quality preference.
func (s *Service) GetBestSource(trackID, preferredQuality string) (*TrackSource, error) {
	sources, err := s.repo.GetSources(trackID)
	if err != nil {
		return nil, err
	}

	qualityOrder := map[string]int{
		"hi_res":   5,
		"lossless": 4,
		"high":     3,
		"medium":   2,
		"low":      1,
	}

	var best *TrackSource
	bestRank := -1
	for i := range sources {
		if !sources[i].Available {
			continue
		}
		rank := qualityOrder[strings.ToLower(sources[i].Quality)]
		if rank >= bestRank {
			best = &sources[i]
			bestRank = rank
		}
	}

	return best, nil
}

func normalizeTitle(title string) string {
	return strings.ToLower(strings.TrimSpace(title))
}

func generateTrackID(t Track) string {
	return fmt.Sprintf("%s-%s", t.ArtistID, t.ISRC)
}
