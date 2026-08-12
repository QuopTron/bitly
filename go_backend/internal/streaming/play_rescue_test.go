package streaming

import (
	"testing"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

func TestBestMatchRejectsWrongVersion(t *testing.T) {
	results := []provider.TrackResult{
		{Title: "Bohemian Rhapsody (Official Video)", Artist: "Queen"},
		{Title: "Bohemian Rhapsody (Live at Wembley)", Artist: "Queen"},
		{Title: "Some Other Song", Artist: "Random Band"},
	}
	best, tScore, aScore := bestMatch("Bohemian Rhapsody", "Queen", results)
	if best == nil || best.Title != results[0].Title {
		t.Fatalf("expected top match, got %+v", best)
	}
	if tScore < 2 || aScore < 2 {
		t.Fatalf("expected strong match (t=%v a=%v)", tScore, aScore)
	}
}

func TestBestMatchSkipsUnrelated(t *testing.T) {
	results := []provider.TrackResult{
		{Title: "Completely Unrelated Track", Artist: "Some Band"},
		{Title: "Another Thing", Artist: "Other"},
	}
	best, tScore, aScore := bestMatch("Bohemian Rhapsody", "Queen", results)
	if best != nil {
		t.Fatalf("expected no acceptable match, got %+v", best)
	}
	if tScore >= 2 || aScore >= 2 {
		t.Fatalf("expected weak scores (t=%v a=%v)", tScore, aScore)
	}
}

func TestNormFoldsAccentsAndNoise(t *testing.T) {
	if got := norm("Café de Paris (Official Audio)"); got != "cafe de paris" {
		t.Fatalf("norm mismatch: %q", got)
	}
	if got := norm("À Voir"); got != "a voir" {
		t.Fatalf("fold mismatch: %q", got)
	}
}
