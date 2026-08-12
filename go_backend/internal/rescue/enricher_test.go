package rescue

import (
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

func TestNewEnricher(t *testing.T) {
	reg := provider.NewRegistry()
	e := NewEnricher(reg)
	if e == nil {
		t.Fatal("expected non-nil enricher")
	}
}

func TestEnrichFromISRC_NoProviders(t *testing.T) {
	reg := provider.NewRegistry()
	e := NewEnricher(reg)
	result, err := e.EnrichFromISRC("GBUM71029604")
	if err == nil {
		t.Error("expected error with no providers")
	}
	if result != nil {
		t.Errorf("expected nil result, got %+v", result)
	}
}

func TestEnrichFromISRC_Found(t *testing.T) {
	reg := provider.NewRegistry()
	reg.Register(&mockRescueProvider{
		name: "deezer",
		tracks: map[string]*provider.TrackResult{
			"123": {ID: "deezer:123", Title: "Song", ISRC: "GBUM71029604", Artist: "Queen", Album: "Greatest Hits", Duration: 180000},
		},
	})
	e := NewEnricher(reg)
	result, err := e.EnrichFromISRC("GBUM71029604")
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result == nil {
		t.Fatal("expected non-nil result")
	}
	if result.ISRC != "GBUM71029604" {
		t.Errorf("expected ISRC GBUM71029604, got %s", result.ISRC)
	}
}
