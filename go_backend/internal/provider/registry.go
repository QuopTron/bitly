// Package provider manages all music source providers.
// Each provider implements the Provider interface for searching,
// metadata lookup, and stream URL retrieval.
package provider

// TrackResult is the normalized track result across all providers.
type TrackResult struct {
	ID        string `json:"id"`
	Title     string `json:"title"`
	Artist    string `json:"artist"`
	ArtistID  string `json:"artistId"`
	Album     string `json:"album"`
	AlbumID   string `json:"albumId"`
	Duration  int    `json:"durationMs"`
	ISRC      string `json:"isrc"`
	CoverURL  string `json:"coverUrl"`
	Provider  string `json:"provider"`
}

// AlbumResult is the normalized album result across all providers.
type AlbumResult struct {
	ID          string `json:"id"`
	Title       string `json:"title"`
	Artist      string `json:"artist"`
	ArtistID    string `json:"artistId"`
	CoverURL    string `json:"coverUrl"`
	ReleaseDate string `json:"releaseDate"`
	TrackCount  int    `json:"trackCount"`
	Provider    string `json:"provider"`
}

// ArtistResult is the normalized artist result.
type ArtistResult struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	PictureURL string `json:"pictureUrl"`
	Fans      int    `json:"fans"`
	Provider  string `json:"provider"`
}

// PlaylistResult is the normalized playlist result across all providers.
type PlaylistResult struct {
	ID          string `json:"id"`
	Title       string `json:"title"`
	Description string `json:"description,omitempty"`
	Creator     string `json:"creator"`
	TrackCount  int    `json:"trackCount"`
	CoverURL    string `json:"coverUrl,omitempty"`
	Provider    string `json:"provider"`
}

// Provider defines the interface all music providers must implement.
type Provider interface {
	Name() string
	SearchTracks(query string, limit int) ([]TrackResult, error)
	SearchAlbums(query string, limit int) ([]AlbumResult, error)
	SearchArtists(query string, limit int) ([]ArtistResult, error)
	SearchPlaylists(query string, limit int) ([]PlaylistResult, error)
	GetTrack(id string) (*TrackResult, error)
	GetTrackByISRC(isrc string) (*TrackResult, error)
	GetAlbum(id string) (*AlbumResult, error)
	GetArtist(id string) (*ArtistResult, error)
	GetStreamURL(id, quality string) (string, error)
}

// Registry holds all registered provider instances.
type Registry struct {
	items map[string]Provider
}

// NewRegistry creates an empty provider registry.
func NewRegistry() *Registry {
	return &Registry{items: make(map[string]Provider)}
}

// Register adds a provider to the registry.
func (r *Registry) Register(p Provider) {
	r.items[p.Name()] = p
}

// Get returns a provider by name, or nil if not found.
func (r *Registry) Get(name string) Provider {
	return r.items[name]
}

// All returns all registered providers.
func (r *Registry) All() []Provider {
	all := make([]Provider, 0, len(r.items))
	for _, p := range r.items {
		all = append(all, p)
	}
	return all
}

// Names returns the names of all registered providers.
func (r *Registry) Names() []string {
	names := make([]string, 0, len(r.items))
	for n := range r.items {
		names = append(names, n)
	}
	return names
}
