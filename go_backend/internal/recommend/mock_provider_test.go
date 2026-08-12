package recommend

import (
	"errors"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// mockProvider implements provider.Provider for testing.
type mockProvider struct {
	name           string
	trackResults   map[string][]provider.TrackResult
	artistResults  map[string][]provider.ArtistResult
	trackByID      map[string]*provider.TrackResult
	searchTracksFn func(query string, limit int) ([]provider.TrackResult, error)
	searchArtFn    func(query string, limit int) ([]provider.ArtistResult, error)
	getTrackFn     func(id string) (*provider.TrackResult, error)
}

func (m *mockProvider) Name() string { return m.name }

func (m *mockProvider) SearchTracks(query string, limit int) ([]provider.TrackResult, error) {
	if m.searchTracksFn != nil {
		return m.searchTracksFn(query, limit)
	}
	if m.trackResults != nil {
		if res, ok := m.trackResults[query]; ok {
			return res, nil
		}
	}
	return nil, nil
}

func (m *mockProvider) SearchAlbums(query string, limit int) ([]provider.AlbumResult, error) {
	return nil, nil
}

func (m *mockProvider) SearchArtists(query string, limit int) ([]provider.ArtistResult, error) {
	if m.searchArtFn != nil {
		return m.searchArtFn(query, limit)
	}
	if m.artistResults != nil {
		if res, ok := m.artistResults[query]; ok {
			return res, nil
		}
	}
	return nil, nil
}

func (m *mockProvider) SearchPlaylists(query string, limit int) ([]provider.PlaylistResult, error) {
	return nil, nil
}

func (m *mockProvider) GetTrack(id string) (*provider.TrackResult, error) {
	if m.getTrackFn != nil {
		return m.getTrackFn(id)
	}
	if m.trackByID != nil {
		if t, ok := m.trackByID[id]; ok {
			return t, nil
		}
	}
	return nil, errors.New("not found")
}

func (m *mockProvider) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	return nil, errors.New("not found")
}

func (m *mockProvider) GetAlbum(id string) (*provider.AlbumResult, error) {
	return nil, errors.New("not found")
}

func (m *mockProvider) GetArtist(id string) (*provider.ArtistResult, error) {
	return nil, errors.New("not found")
}

func (m *mockProvider) GetStreamURL(id, quality string) (string, error) {
	return "", errors.New("no stream")
}
