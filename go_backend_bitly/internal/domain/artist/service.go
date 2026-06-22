package artist

// Service provides business operations for artists.
type Service struct {
	repo *Repository
}

// NewService creates an artist service.
func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

// GetOrCreate finds or creates an artist.
func (s *Service) GetOrCreate(a Artist) (*Artist, error) {
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

// SearchByName searches artists by name.
func (s *Service) SearchByName(name string) ([]Artist, error) {
	return s.repo.SearchByName(name)
}
