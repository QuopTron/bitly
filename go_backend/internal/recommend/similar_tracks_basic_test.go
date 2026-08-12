package recommend

import (
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

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
				{ID: "1", Title: "Original Song", Artist: "Artist A", Provider: "test-provider"},
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
				{ID: "1", Title: "Song A", Artist: "Artist A", Provider: "test-provider"},
			}, nil
		},
	})

	e := New(reg)
	results, _ := e.SimilarTracks("Original", "Artist", 10)
	if len(results) != 1 {
		t.Errorf("expected 1 result after dedup, got %d", len(results))
	}
}
