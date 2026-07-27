// Package search provides a multi-provider search engine with
// deduplication, ranking, and automatic fallback between providers.
package search

import (
	"time"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// Config defines search engine behavior.
type Config struct {
	Timeout        time.Duration
	MaxResults     int
	EnableFallback bool
}

// DefaultConfig returns sensible search defaults.
func DefaultConfig() Config {
	return Config{
		Timeout:        10 * time.Second,
		MaxResults:     20,
		EnableFallback: true,
	}
}

// SearchResult is the final deduplicated search result.
type SearchResult struct {
	Track    provider.TrackResult `json:"track"`
	Score    float64              `json:"score"`
	Source   string               `json:"source"` // "primary" or "fallback"
}

// Results is a sortable slice of SearchResult.
type Results []SearchResult

func (r Results) Len() int           { return len(r) }
func (r Results) Less(i, j int) bool { return r[i].Score > r[j].Score }
func (r Results) Swap(i, j int)      { r[i], r[j] = r[j], r[i] }
