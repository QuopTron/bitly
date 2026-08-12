package rescue

import (
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// mockRescueProvider implements provider.Provider for testing.
type mockRescueProvider struct {
	name      string
	tracks    map[string]*provider.TrackResult
	streamURL string
}

func (m *mockRescueProvider) Name() string                                         { return m.name }
func (m *mockRescueProvider) SearchTracks(q string, l int) ([]provider.TrackResult, error) {
	if t, ok := m.tracks[q]; ok && t != nil {
		return []provider.TrackResult{*t}, nil
	}
	return nil, nil
}
func (m *mockRescueProvider) SearchAlbums(q string, l int) ([]provider.AlbumResult, error)   { return nil, nil }
func (m *mockRescueProvider) SearchArtists(q string, l int) ([]provider.ArtistResult, error)  { return nil, nil }
func (m *mockRescueProvider) SearchPlaylists(q string, l int) ([]provider.PlaylistResult, error) { return nil, nil }
func (m *mockRescueProvider) GetTrack(id string) (*provider.TrackResult, error) {
	if t, ok := m.tracks[id]; ok {
		return t, nil
	}
	return nil, nil
}
func (m *mockRescueProvider) GetTrackByISRC(isrc string) (*provider.TrackResult, error) {
	for _, t := range m.tracks {
		if t.ISRC == isrc {
			return t, nil
		}
	}
	return nil, nil
}
func (m *mockRescueProvider) GetAlbum(id string) (*provider.AlbumResult, error)   { return nil, nil }
func (m *mockRescueProvider) GetArtist(id string) (*provider.ArtistResult, error) { return nil, nil }
func (m *mockRescueProvider) GetStreamURL(id, q string) (string, error)           { return m.streamURL, nil }

func TestNewRescuer(t *testing.T) {
	reg := provider.NewRegistry()
	r := New(reg)
	if r == nil {
		t.Fatal("expected non-nil rescuer")
	}
}

func TestRescueByISRC_Found(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockRescueProvider{
		name: "deezer",
		tracks: map[string]*provider.TrackResult{
			"123": {ID: "deezer:123", Title: "Song", ISRC: "GBUM71029604", Provider: "deezer"},
		},
		streamURL: "https://stream.deezer.com/test",
	})
	r := New(reg)
	result := r.RescueByISRC("GBUM71029604", "Song", "Artist", "FLAC")
	if result == nil {
		t.Fatal("expected non-nil result")
	}
	if result.Provider != "deezer" {
		t.Errorf("expected deezer provider, got %s", result.Provider)
	}
	if result.StreamURL == "" {
		t.Error("expected non-empty stream URL")
	}
	if !result.Found {
		t.Error("expected Found=true")
	}
}

func TestRescueByISRC_NotFound(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockRescueProvider{
		name:   "empty",
		tracks: map[string]*provider.TrackResult{},
	})
	r := New(reg)
	result := r.RescueByISRC("NONEXISTENT", "Song", "Artist", "FLAC")
	if result == nil {
		t.Fatal("expected non-nil result")
	}
	if result.Found {
		t.Error("expected Found=false for missing ISRC")
	}
	if result.Error == "" {
		t.Error("expected error message for missing ISRC")
	}
}

func TestRescueByISRC_NoStreamURL(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockRescueProvider{
		name: "spotify",
		tracks: map[string]*provider.TrackResult{
			"123": {ID: "spotify:123", Title: "Song", ISRC: "GBUM71029604"},
		},
		streamURL: "",
	})
	r := New(reg)
	result := r.RescueByISRC("GBUM71029604", "Song", "Artist", "FLAC")
	if result == nil {
		t.Fatal("expected non-nil result")
	}
	if !result.Found {
		t.Log("rescue didn't find the track (no stream URL provider)")
	}
}

func TestRescueBatch(t *testing.T) {
	reg := provider.NewRegistry()
	r := New(reg)
	reqs := []RescueRequest{
		{ISRC: "GBUM71029604", TrackName: "Song", ArtistName: "Artist", Quality: "FLAC"},
	}
	results := r.RescueBatch(reqs)
	if results == nil {
		t.Fatal("expected non-nil results")
	}
	if len(results) != 1 {
		t.Errorf("expected 1 result, got %d", len(results))
	}
}
