package gobackend

import (
	"encoding/json"
	"sync"
	"time"
)

const searchGlobalTimeout = 4 * time.Second

// =========================================================================
// STREAMING SEARCH BUFFER
// =========================================================================

// searchStreamState holds partial results for a streaming search session.
// Flutter polls GetSearchStreamResults() to receive results incrementally
// as each provider completes, instead of waiting for the full 9s timeout.
type searchStreamState struct {
	mu         sync.Mutex
	items      []FeedItemGo
	done       bool
	generation int64
}

var currentSearchStream = &searchStreamState{}

// SearchStream starts a parallel search across all providers and returns
// immediately. Results accumulate in a buffer that Flutter reads via
// GetSearchStreamResults(). Returns the generation ID for this search.
func SearchStream(payload string) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}

	var params struct {
		Query  string `json:"query"`
		Limit  int    `json:"limit"`
		Source string `json:"source"`
		Type   string `json:"type"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}

	query := params.Query
	limit := params.Limit
	if limit < 1 {
		limit = 20
	}
	source := params.Source
	searchType := params.Type

	currentSearchStream.mu.Lock()
	currentSearchStream.generation++
	gen := currentSearchStream.generation
	currentSearchStream.items = nil
	currentSearchStream.done = false
	currentSearchStream.mu.Unlock()

	go runSearchStream(gen, query, limit, source, searchType)

	data, _ := json.Marshal(map[string]interface{}{
		"generation": gen,
	})
	return string(data)
}
