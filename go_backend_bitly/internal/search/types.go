package search

// SearchMode defines how search results are returned.
type SearchMode string

const (
	SearchModeUnified  SearchMode = "unified"
	SearchModeBySource SearchMode = "by_source"
	SearchModeSingle   SearchMode = "single"
)

// SearchRequest describes a search query.
type SearchRequest struct {
	Query  string     `json:"query"`
	Type   string     `json:"type"` // track, album, artist, playlist
	Mode   SearchMode `json:"mode"`
	Source string     `json:"source,omitempty"`
	Page   int        `json:"page"`
	Limit  int        `json:"limit"`
}

// SearchResult holds results from a search operation.
type SearchResult struct {
	Mode             SearchMode            `json:"mode"`
	Query            string                `json:"query"`
	Type             string                `json:"type"`
	Unified          []UnifiedResult       `json:"unified,omitempty"`
	BySource         map[string][]RawResult `json:"by_source,omitempty"`
	Single           []RawResult           `json:"single,omitempty"`
	SourcesQueried   []string              `json:"sources_queried"`
	SourcesResponded []string              `json:"sources_responded"`
	DurationMs       int64                 `json:"duration_ms"`
}

// UnifiedResult is a deduplicated result with sources from multiple providers.
type UnifiedResult struct {
	ID                string                       `json:"id"`
	Title             string                       `json:"title"`
	Artist            string                       `json:"artist"`
	Album             string                       `json:"album"`
	DurationMs        int64                        `json:"duration_ms"`
	ISRC              string                       `json:"isrc"`
	Sources           map[string]SourceAvailability `json:"sources"`
	BestSource        string                       `json:"best_source"`
	Covers            map[string]string            `json:"covers"`
}

// SourceAvailability describes availability from a specific provider.
type SourceAvailability struct {
	Available bool   `json:"available"`
	Quality   string `json:"quality"`
}

// RawResult is a result from a single provider before deduplication.
type RawResult struct {
	ID        string `json:"id"`
	Title     string `json:"title"`
	Artist    string `json:"artist"`
	Album     string `json:"album"`
	Duration  int64  `json:"duration_ms"`
	ISRC      string `json:"isrc"`
	Source    string `json:"source"`
	CoverURL  string `json:"cover_url"`
}
