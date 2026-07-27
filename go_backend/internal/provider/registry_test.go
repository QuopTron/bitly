package provider

import (
	"testing"
)

// mockProvider implements Provider for testing.
type mockProvider struct {
	name string
}

func (m *mockProvider) Name() string                                         { return m.name }
func (m *mockProvider) SearchTracks(q string, l int) ([]TrackResult, error)  { return nil, nil }
func (m *mockProvider) SearchAlbums(q string, l int) ([]AlbumResult, error)  { return nil, nil }
func (m *mockProvider) SearchArtists(q string, l int) ([]ArtistResult, error){ return nil, nil }
func (m *mockProvider) GetTrack(id string) (*TrackResult, error)            { return nil, nil }
func (m *mockProvider) GetTrackByISRC(isrc string) (*TrackResult, error)    { return nil, nil }
func (m *mockProvider) GetAlbum(id string) (*AlbumResult, error)            { return nil, nil }
func (m *mockProvider) GetArtist(id string) (*ArtistResult, error)          { return nil, nil }
func (m *mockProvider) GetStreamURL(id, q string) (string, error)           { return "", nil }

func TestRegistryRegisterGet(t *testing.T) {
	r := NewRegistry()
	r.Register(&mockProvider{name: "deezer"})

	p := r.Get("deezer")
	if p == nil {
		t.Fatal("expected provider")
	}
	if p.Name() != "deezer" {
		t.Errorf("expected deezer, got %s", p.Name())
	}
}

func TestRegistryGetMissing(t *testing.T) {
	r := NewRegistry()
	p := r.Get("nonexistent")
	if p != nil {
		t.Error("expected nil for missing provider")
	}
}

func TestRegistryAll(t *testing.T) {
	r := NewRegistry()
	r.Register(&mockProvider{name: "deezer"})
	r.Register(&mockProvider{name: "qobuz"})
	r.Register(&mockProvider{name: "tidal"})

	all := r.All()
	if len(all) != 3 {
		t.Errorf("expected 3 providers, got %d", len(all))
	}
}

func TestRegistryAllEmpty(t *testing.T) {
	r := NewRegistry()
	all := r.All()
	if len(all) != 0 {
		t.Errorf("expected 0 providers, got %d", len(all))
	}
}

func TestRegistryNames(t *testing.T) {
	r := NewRegistry()
	r.Register(&mockProvider{name: "deezer"})
	r.Register(&mockProvider{name: "qobuz"})

	names := r.Names()
	if len(names) != 2 {
		t.Fatalf("expected 2 names, got %d", len(names))
	}

	seen := make(map[string]bool)
	for _, n := range names {
		seen[n] = true
	}

	if !seen["deezer"] || !seen["qobuz"] {
		t.Error("expected deezer and qobuz in names")
	}
}

func TestRegistryOverwrite(t *testing.T) {
	r := NewRegistry()
	r.Register(&mockProvider{name: "test"})
	r.Register(&mockProvider{name: "test"}) // overwrite

	all := r.All()
	if len(all) != 1 {
		t.Errorf("expected 1 provider after overwrite, got %d", len(all))
	}
}
