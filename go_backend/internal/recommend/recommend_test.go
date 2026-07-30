package recommend

import (
	"errors"
	"testing"

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

func TestNew(t *testing.T) {
	reg := provider.NewRegistry()
	e := New(reg)
	if e == nil {
		t.Fatal("expected non-nil engine")
	}
	if e.registry != reg {
		t.Error("engine.registry should match the passed registry")
	}
}

func TestSimilarTracks_ReturnsFromProvider(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockProvider{
		name: "test-provider",
		searchTracksFn: func(query string, limit int) ([]provider.TrackResult, error) {
			return []provider.TrackResult{
				{ID: "1", Title: "Another Song", Artist: "Artist A", Provider: "test-provider"},
				{ID: "2", Title: "Different Track", Artist: "Artist B", Provider: "test-provider"},
			}, nil
		},
	})

	e := New(reg)
	results, err := e.SimilarTracks("Original Song", "Artist A", 10)
	if err != nil {
		t.Fatalf("SimilarTracks failed: %v", err)
	}
	if len(results) != 2 {
		t.Fatalf("expected 2 results, got %d", len(results))
	}
}

func TestSimilarTracks_ExcludesSameTrack(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockProvider{
		name: "test-provider",
		searchTracksFn: func(query string, limit int) ([]provider.TrackResult, error) {
			return []provider.TrackResult{
				// This is the exact same track - should be filtered out
				{ID: "1", Title: "Original Song", Artist: "Artist A", Provider: "test-provider"},
				// This is a different song by same artist - should be kept
				{ID: "2", Title: "Different Song", Artist: "Artist A", Provider: "test-provider"},
			}, nil
		},
	})

	e := New(reg)
	results, err := e.SimilarTracks("Original Song", "Artist A", 10)
	if err != nil {
		t.Fatalf("SimilarTracks failed: %v", err)
	}
	if len(results) != 1 {
		t.Fatalf("expected 1 result (filtered out original), got %d", len(results))
	}
	if results[0].ID != "2" {
		t.Errorf("expected result ID '2', got %q", results[0].ID)
	}
}

func TestSimilarTracks_DedupByID(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockProvider{
		name: "test-provider",
		searchTracksFn: func(query string, limit int) ([]provider.TrackResult, error) {
			return []provider.TrackResult{
				{ID: "1", Title: "Song A", Artist: "Artist A", Provider: "test-provider"},
				{ID: "1", Title: "Song A", Artist: "Artist A", Provider: "test-provider"}, // Duplicate ID
			}, nil
		},
	})

	e := New(reg)
	results, _ := e.SimilarTracks("Original", "Artist", 10)
	if len(results) != 1 {
		t.Errorf("expected 1 result after dedup, got %d", len(results))
	}
}

func TestSimilarTracks_MultipleProviders(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockProvider{
		name: "provider-a",
		searchTracksFn: func(query string, limit int) ([]provider.TrackResult, error) {
			return []provider.TrackResult{
				{ID: "a1", Title: "Song from A", Artist: "Artist X", Provider: "provider-a"},
			}, nil
		},
	})
	reg.Register(&mockProvider{
		name: "provider-b",
		searchTracksFn: func(query string, limit int) ([]provider.TrackResult, error) {
			return []provider.TrackResult{
				{ID: "b1", Title: "Song from B", Artist: "Artist Y", Provider: "provider-b"},
			}, nil
		},
	})

	e := New(reg)
	results, err := e.SimilarTracks("Original", "Artist", 10)
	if err != nil {
		t.Fatalf("SimilarTracks failed: %v", err)
	}
	if len(results) != 2 {
		t.Fatalf("expected 2 results (one from each provider), got %d", len(results))
	}
}

func TestSimilarTracks_RespectsLimit(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockProvider{
		name: "test-provider",
		searchTracksFn: func(query string, limit int) ([]provider.TrackResult, error) {
			results := make([]provider.TrackResult, 10)
			for i := 0; i < 10; i++ {
				results[i] = provider.TrackResult{
					ID:    string(rune('a' + i)),
					Title: "Song",
					Artist: "Artist",
				}
			}
			return results, nil
		},
	})

	e := New(reg)
	results, _ := e.SimilarTracks("Original", "Artist", 3)
	if len(results) > 3 {
		t.Errorf("expected at most 3 results, got %d", len(results))
	}
}

func TestSimilarTracks_ProviderError(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockProvider{
		name: "broken-provider",
		searchTracksFn: func(query string, limit int) ([]provider.TrackResult, error) {
			return nil, errors.New("provider error")
		},
	})
	reg.Register(&mockProvider{
		name: "good-provider",
		searchTracksFn: func(query string, limit int) ([]provider.TrackResult, error) {
			return []provider.TrackResult{
				{ID: "1", Title: "Working Song", Artist: "Artist", Provider: "good-provider"},
			}, nil
		},
	})

	e := New(reg)
	results, err := e.SimilarTracks("Original", "Artist", 10)
	if err != nil {
		t.Fatalf("SimilarTracks should ignore provider errors: %v", err)
	}
	if len(results) != 1 {
		t.Errorf("expected 1 result from good provider, got %d", len(results))
	}
}

func TestSimilarTracks_NilResults(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockProvider{
		name: "test-provider",
		searchTracksFn: func(query string, limit int) ([]provider.TrackResult, error) {
			return nil, nil
		},
	})

	e := New(reg)
	results, err := e.SimilarTracks("Original", "Artist", 10)
	if err != nil {
		t.Fatalf("SimilarTracks should handle nil results: %v", err)
	}
	if len(results) != 0 {
		t.Errorf("expected 0 results, got %d", len(results))
	}
}

func TestSimilarTracks_DefaultLimit(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockProvider{
		name: "test-provider",
		searchTracksFn: func(query string, limit int) ([]provider.TrackResult, error) {
			if limit != 10 {
				t.Errorf("expected default limit 10, got %d", limit)
			}
			return []provider.TrackResult{
				{ID: "1", Title: "Song", Artist: "Artist", Provider: "test-provider"},
			}, nil
		},
	})

	e := New(reg)
	e.SimilarTracks("Original", "Artist", 0) // 0 should become 10
}

// ─── SimilarArtists ─────────────────────────────────────────

func TestSimilarArtists_ReturnsFromProvider(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockProvider{
		name: "test-provider",
		searchArtFn: func(query string, limit int) ([]provider.ArtistResult, error) {
			return []provider.ArtistResult{
				{ID: "1", Name: "Similar Artist", Provider: "test-provider"},
			}, nil
		},
	})

	e := New(reg)
	results, err := e.SimilarArtists("Original Artist", 10)
	if err != nil {
		t.Fatalf("SimilarArtists failed: %v", err)
	}
	if len(results) != 1 {
		t.Fatalf("expected 1 result, got %d", len(results))
	}
	if results[0].Name != "Similar Artist" {
		t.Errorf("expected 'Similar Artist', got %q", results[0].Name)
	}
}

func TestSimilarArtists_ExcludesSelf(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockProvider{
		name: "test-provider",
		searchArtFn: func(query string, limit int) ([]provider.ArtistResult, error) {
			return []provider.ArtistResult{
				{ID: "1", Name: "Original Artist", Provider: "test-provider"},
				{ID: "2", Name: "Different Artist", Provider: "test-provider"},
			}, nil
		},
	})

	e := New(reg)
	results, _ := e.SimilarArtists("Original Artist", 10)
	if len(results) != 1 {
		t.Fatalf("expected 1 result (filtered self), got %d", len(results))
	}
	if results[0].Name == "Original Artist" {
		t.Error("should have filtered out 'Original Artist'")
	}
}

func TestSimilarArtists_NoResults(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockProvider{
		name: "test-provider",
		searchArtFn: func(query string, limit int) ([]provider.ArtistResult, error) {
			return nil, nil
		},
	})

	e := New(reg)
	results, err := e.SimilarArtists("Unknown Artist", 10)
	if err != nil {
		t.Fatalf("SimilarArtists failed: %v", err)
	}
	if len(results) != 0 {
		t.Errorf("expected 0 results, got %d", len(results))
	}
}

func TestSimilarArtists_DefaultLimit(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockProvider{
		name: "test-provider",
		searchArtFn: func(query string, limit int) ([]provider.ArtistResult, error) {
			if limit != 10 {
				t.Errorf("expected default limit 10, got %d", limit)
			}
			return nil, nil
		},
	})

	e := New(reg)
	e.SimilarArtists("Artist", 0)
}

// ─── GetTrack ───────────────────────────────────────────────

func TestGetTrack_Found(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockProvider{
		name: "provider-a",
		getTrackFn: func(id string) (*provider.TrackResult, error) {
			if id == "track-123" {
				return &provider.TrackResult{
					ID:     "track-123",
					Title:  "Found Track",
					Artist: "Some Artist",
				}, nil
			}
			return nil, errors.New("not found")
		},
	})
	reg.Register(&mockProvider{
		name: "provider-b",
		getTrackFn: func(id string) (*provider.TrackResult, error) {
			return nil, errors.New("not found")
		},
	})

	track, err := GetTrack(reg, "track-123")
	if err != nil {
		t.Fatalf("GetTrack failed: %v", err)
	}
	if track == nil {
		t.Fatal("expected non-nil track")
	}
	if track.Title != "Found Track" {
		t.Errorf("expected 'Found Track', got %q", track.Title)
	}
}

func TestGetTrack_NotFound(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockProvider{
		name: "test-provider",
		getTrackFn: func(id string) (*provider.TrackResult, error) {
			return nil, errors.New("not found")
		},
	})

	track, err := GetTrack(reg, "nonexistent")
	if err == nil {
		t.Fatal("expected error for nonexistent track")
	}
	if track != nil {
		t.Errorf("expected nil track, got %+v", track)
	}
}

func TestGetTrack_EmptyRegistry(t *testing.T) {
	reg := provider.NewRegistry()
	track, err := GetTrack(reg, "any")
	if err == nil {
		t.Fatal("expected error with empty registry")
	}
	if track != nil {
		t.Errorf("expected nil track, got %+v", track)
	}
}

func TestGetTrack_SecondProviderFallback(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockProvider{
		name: "broken-provider",
		getTrackFn: func(id string) (*provider.TrackResult, error) {
			return nil, errors.New("internal error")
		},
	})
	reg.Register(&mockProvider{
		name: "working-provider",
		getTrackFn: func(id string) (*provider.TrackResult, error) {
			return &provider.TrackResult{
				ID:    "track-456",
				Title: "Fallback Track",
			}, nil
		},
	})

	track, err := GetTrack(reg, "track-456")
	if err != nil {
		t.Fatalf("GetTrack should fallback to working provider: %v", err)
	}
	if track.Title != "Fallback Track" {
		t.Errorf("expected 'Fallback Track', got %q", track.Title)
	}
}

// ─── Note ────────────────────────────────────────────────────
//
// These tests use mock providers that return canned data.
// In production, SimilarTracks and SimilarArtists make real
// HTTP calls through the registered providers. The mock approach
// tests the recommendation logic (dedup, filtering, fallback)
// without requiring network access or API credentials.
