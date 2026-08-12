package recommend

import (
	"errors"
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

func TestSimilarArtists_MultipleProviders(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockProvider{
		name: "provider-a",
		searchArtFn: func(query string, limit int) ([]provider.ArtistResult, error) {
			return []provider.ArtistResult{
				{ID: "a1", Name: "Artist A", Provider: "provider-a"},
			}, nil
		},
	})
	reg.Register(&mockProvider{
		name: "provider-b",
		searchArtFn: func(query string, limit int) ([]provider.ArtistResult, error) {
			return []provider.ArtistResult{
				{ID: "b1", Name: "Artist B", Provider: "provider-b"},
			}, nil
		},
	})

	e := New(reg)
	results, err := e.SimilarArtists("Original", 10)
	if err != nil {
		t.Fatalf("SimilarArtists failed: %v", err)
	}
	if len(results) != 2 {
		t.Fatalf("expected 2 results, got %d", len(results))
	}
}

func TestSimilarArtists_RespectsLimit(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockProvider{
		name: "test-provider",
		searchArtFn: func(query string, limit int) ([]provider.ArtistResult, error) {
			results := make([]provider.ArtistResult, 10)
			for i := 0; i < 10; i++ {
				results[i] = provider.ArtistResult{
					ID:   string(rune('a' + i)),
					Name: "Artist",
				}
			}
			return results, nil
		},
	})

	e := New(reg)
	results, _ := e.SimilarArtists("Original", 3)
	if len(results) > 3 {
		t.Errorf("expected at most 3 results, got %d", len(results))
	}
}

func TestSimilarArtists_ProviderError(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockProvider{
		name: "broken",
		searchArtFn: func(query string, limit int) ([]provider.ArtistResult, error) {
			return nil, errors.New("error")
		},
	})
	reg.Register(&mockProvider{
		name: "good",
		searchArtFn: func(query string, limit int) ([]provider.ArtistResult, error) {
			return []provider.ArtistResult{
				{ID: "1", Name: "Working Artist", Provider: "good"},
			}, nil
		},
	})

	e := New(reg)
	results, err := e.SimilarArtists("Original", 10)
	if err != nil {
		t.Fatalf("SimilarArtists should ignore provider errors: %v", err)
	}
	if len(results) != 1 {
		t.Errorf("expected 1 result from good provider, got %d", len(results))
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
	e.SimilarArtists("Original", 0)
}
