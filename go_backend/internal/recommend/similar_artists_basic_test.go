package recommend

import (
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

func TestSimilarArtists_ReturnsFromProvider(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockProvider{
		name: "test-provider",
		searchArtFn: func(query string, limit int) ([]provider.ArtistResult, error) {
			return []provider.ArtistResult{
				{ID: "1", Name: "Artist X", Provider: "test-provider"},
				{ID: "2", Name: "Artist Y", Provider: "test-provider"},
			}, nil
		},
	})

	e := New(reg)
	results, err := e.SimilarArtists("Original Artist", 10)
	if err != nil {
		t.Fatalf("SimilarArtists failed: %v", err)
	}
	if len(results) != 2 {
		t.Fatalf("expected 2 results, got %d", len(results))
	}
}

func TestSimilarArtists_ExcludesSameArtist(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockProvider{
		name: "test-provider",
		searchArtFn: func(query string, limit int) ([]provider.ArtistResult, error) {
			return []provider.ArtistResult{
				{ID: "1", Name: "Original Artist", Provider: "test-provider"},
				{ID: "2", Name: "Related Artist", Provider: "test-provider"},
			}, nil
		},
	})

	e := New(reg)
	results, err := e.SimilarArtists("Original Artist", 10)
	if err != nil {
		t.Fatalf("SimilarArtists failed: %v", err)
	}
	if len(results) != 1 {
		t.Fatalf("expected 1 result (filtered out original), got %d", len(results))
	}
	if results[0].ID != "2" {
		t.Errorf("expected result ID '2', got %q", results[0].ID)
	}
}

func TestSimilarArtists_DedupByID(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockProvider{
		name: "test-provider",
		searchArtFn: func(query string, limit int) ([]provider.ArtistResult, error) {
			return []provider.ArtistResult{
				{ID: "1", Name: "Artist A", Provider: "test-provider"},
				{ID: "1", Name: "Artist A", Provider: "test-provider"},
			}, nil
		},
	})

	e := New(reg)
	results, _ := e.SimilarArtists("Original", 10)
	if len(results) != 1 {
		t.Errorf("expected 1 result after dedup, got %d", len(results))
	}
}
