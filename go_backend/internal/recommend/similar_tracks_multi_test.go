package recommend

import (
	"errors"
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

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
					Title: "Song", Artist: "Artist",
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
	e.SimilarTracks("Original", "Artist", 0)
}
