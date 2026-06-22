package core

type SelectedSource struct {
	Provider   string  `json:"provider"`
	ProviderID string  `json:"provider_id"`
	Quality    string  `json:"quality"`
	URL        string  `json:"url"`
	Confidence float64 `json:"confidence"`
}

type AvailabilityChecker interface {
	CheckTrackAvailability(spotifyID, isrc string) (interface{}, error)
}

type ISRCResolver interface {
	ResolveByISRC(isrc string) (interface{}, error)
}

type TrackAvail struct {
	Deezer   bool   `json:"deezer"`
	Tidal    bool   `json:"tidal"`
	Qobuz    bool   `json:"qobuz"`
	DeezerID string `json:"deezer_id,omitempty"`
	TidalID  string `json:"tidal_id,omitempty"`
	QobuzID  string `json:"qobuz_id,omitempty"`
}

var providerQualityRank = map[string]int{
	"flac":   4,
	"hifi":   3,
	"high":   2,
	"medium": 1,
	"low":    0,
}

type SourceSelector struct {
	registry     *ProviderRegistry
	priority     []string
	availChecker AvailabilityChecker
	isrcResolver ISRCResolver
}

func NewSourceSelector(registry *ProviderRegistry, priority []string) *SourceSelector {
	return &SourceSelector{
		registry: registry,
		priority: priority,
	}
}

func (s *SourceSelector) SetAvailabilityChecker(c AvailabilityChecker) {
	s.availChecker = c
}

func (s *SourceSelector) SetISRCResolver(r ISRCResolver) {
	s.isrcResolver = r
}
