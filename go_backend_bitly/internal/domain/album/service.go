package album

import "github.com/zarz/bitly/go_backend_bitly/internal/domain/track"

// Service provides business operations for albums.
type Service struct {
	repo      *Repository
	trackRepo *track.Repository
}

// NewService creates an album service.
func NewService(repo *Repository, trackRepo *track.Repository) *Service {
	return &Service{repo: repo, trackRepo: trackRepo}
}

// GetOrCreate finds or creates an album.
func (s *Service) GetOrCreate(a Album) (*Album, error) {
	if a.ID != "" {
		existing, err := s.repo.GetByID(a.ID)
		if err == nil && existing != nil {
			return existing, nil
		}
	}
	if err := s.repo.Create(&a); err != nil {
		return nil, err
	}
	return &a, nil
}

// GetTracks returns all tracks belonging to an album.
func (s *Service) GetTracks(albumID string) ([]track.Track, error) {
	return s.trackRepo.GetByAlbum(albumID)
}

// GetTotalDuration returns the total duration of an album in minutes.
func (s *Service) GetTotalDuration(albumID string) (float64, error) {
	tracks, err := s.trackRepo.GetByAlbum(albumID)
	if err != nil {
		return 0, err
	}
	var totalMs int64
	for _, t := range tracks {
		totalMs += t.DurationMs
	}
	return float64(totalMs) / 1000 / 60, nil
}
