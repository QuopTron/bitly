package playlist

import (
	"fmt"
	"time"
)

// Service provides business operations for playlists.
type Service struct {
	repo *Repository
}

// NewService creates a playlist service.
func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

// Create creates a new playlist with validation.
func (s *Service) Create(name, description string) (*Playlist, error) {
	p := &Playlist{
		ID:          fmt.Sprintf("pl_%d", time.Now().UnixNano()),
		Name:        name,
		Description: description,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}
	if err := s.repo.Create(p); err != nil {
		return nil, err
	}
	return p, nil
}
