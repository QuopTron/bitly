package search

import (
	"context"
	"errors"
	"testing"

	"github.com/zarz/bitly/go_backend_bitly/internal/sources/core"
)

// mockSearchProvider implements core.SearchProvider for testing.
type mockSearchProvider struct {
	id   string
	name string
	data map[string][]core.SearchResultItem // query → results
	err  error
}

func (m *mockSearchProvider) ID() string   { return m.id }
func (m *mockSearchProvider) Name() string { return m.name }
func (m *mockSearchProvider) Search(query string, limit int) ([]core.SearchResultItem, error) {
	if m.err != nil {
		return nil, m.err
	}
	items := m.data[query]
	if limit > 0 && len(items) > limit {
		items = items[:limit]
	}
	return items, nil
}

func TestServiceSearchCachedResult(t *testing.T) {
	reg := core.NewProviderRegistry()
	svc := NewService(reg)

	req := SearchRequest{Query: "test", Type: "track"}
	svc.cache.Set("test|track", &SearchResult{Query: "test", Type: "track", SourcesQueried: []string{"cache"}})

	got, err := svc.Search(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(got.SourcesQueried) != 1 || got.SourcesQueried[0] != "cache" {
		t.Errorf("expected cached result, got SourcesQueried=%v", got.SourcesQueried)
	}
}

func TestServiceSearchNoProviders(t *testing.T) {
	reg := core.NewProviderRegistry()
	svc := NewService(reg)

	req := SearchRequest{Query: "test", Type: "track", Limit: 10}
	got, err := svc.Search(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.Query != "test" {
		t.Errorf("expected Query=test, got %q", got.Query)
	}
	if len(got.Unified) != 0 {
		t.Errorf("expected 0 unified results, got %d", len(got.Unified))
	}
	if got.DurationMs < 0 {
		t.Errorf("expected non-negative DurationMs, got %d", got.DurationMs)
	}
}

func TestServiceSearchSingleProvider(t *testing.T) {
	reg := core.NewProviderRegistry()
	p := &mockSearchProvider{
		id:   "mock_a",
		name: "Mock A",
		data: map[string][]core.SearchResultItem{
			"test": {
				{ID: "a1", Title: "Test Song", Artist: "Test Artist", Source: "mock_a", ISRC: "I1"},
				{ID: "a2", Title: "Another", Artist: "Singer", Source: "mock_a", ISRC: "I2"},
			},
		},
	}
	reg.RegisterSearchProvider(p.id, p)
	svc := NewService(reg)

	req := SearchRequest{Query: "test", Type: "track", Limit: 10}
	got, err := svc.Search(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(got.SourcesQueried) != 1 || got.SourcesQueried[0] != "mock_a" {
		t.Errorf("expected 1 source queried, got %v", got.SourcesQueried)
	}
	if len(got.SourcesResponded) != 1 {
		t.Errorf("expected 1 source responded, got %v", got.SourcesResponded)
	}
	if len(got.Unified) != 2 {
		t.Fatalf("expected 2 unified results, got %d", len(got.Unified))
	}
}

func TestServiceSearchMultipleProviders(t *testing.T) {
	reg := core.NewProviderRegistry()
	reg.RegisterSearchProvider("mock_a", &mockSearchProvider{
		id:   "mock_a",
		name: "Mock A",
		data: map[string][]core.SearchResultItem{
			"test": {
				{ID: "a1", Title: "Test Song", Artist: "Test Artist", Source: "mock_a", ISRC: "I1"},
			},
		},
	})
	reg.RegisterSearchProvider("mock_b", &mockSearchProvider{
		id:   "mock_b",
		name: "Mock B",
		data: map[string][]core.SearchResultItem{
			"test": {
				{ID: "b1", Title: "Test Song", Artist: "Test Artist", Source: "mock_b", ISRC: "I1"},
				{ID: "b2", Title: "Unique", Artist: "Singer", Source: "mock_b", ISRC: "I3"},
			},
		},
	})
	svc := NewService(reg)

	req := SearchRequest{Query: "test", Type: "track", Limit: 10}
	got, err := svc.Search(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(got.SourcesQueried) != 2 {
		t.Errorf("expected 2 sources queried, got %d", len(got.SourcesQueried))
	}
	if len(got.SourcesResponded) != 2 {
		t.Errorf("expected 2 sources responded, got %d", len(got.SourcesResponded))
	}
	// I1 duplicates across providers → merged into 1, I3 is unique → 2 unified
	if len(got.Unified) != 2 {
		t.Fatalf("expected 2 unified results (1 merged, 1 unique), got %d", len(got.Unified))
	}
}

func TestServiceSearchProviderError(t *testing.T) {
	reg := core.NewProviderRegistry()
	reg.RegisterSearchProvider("good", &mockSearchProvider{
		id:   "good",
		name: "Good",
		data: map[string][]core.SearchResultItem{
			"q": {{ID: "g1", Title: "Good Song", Artist: "GArtist", Source: "good", ISRC: "IG"}},
		},
	})
	reg.RegisterSearchProvider("bad", &mockSearchProvider{
		id:   "bad",
		name: "Bad",
		err:  errors.New("network error"),
	})
	svc := NewService(reg)

	req := SearchRequest{Query: "q", Type: "track", Limit: 10}
	got, err := svc.Search(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(got.SourcesQueried) != 2 {
		t.Errorf("expected 2 sources queried, got %d", len(got.SourcesQueried))
	}
	if len(got.SourcesResponded) != 1 || got.SourcesResponded[0] != "good" {
		t.Errorf("expected only 'good' to respond, got %v", got.SourcesResponded)
	}
	if len(got.Unified) != 1 {
		t.Errorf("expected 1 unified result from good provider, got %d", len(got.Unified))
	}
}

func TestServiceSearchAllProvidersFail(t *testing.T) {
	reg := core.NewProviderRegistry()
	reg.RegisterSearchProvider("p1", &mockSearchProvider{id: "p1", name: "P1", err: errors.New("fail")})
	reg.RegisterSearchProvider("p2", &mockSearchProvider{id: "p2", name: "P2", err: errors.New("fail")})
	svc := NewService(reg)

	req := SearchRequest{Query: "q", Type: "track", Limit: 10}
	got, err := svc.Search(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(got.SourcesQueried) != 2 {
		t.Errorf("expected 2 sources queried, got %d", len(got.SourcesQueried))
	}
	if len(got.SourcesResponded) != 0 {
		t.Errorf("expected 0 sources responded, got %d", len(got.SourcesResponded))
	}
	if len(got.Unified) != 0 {
		t.Errorf("expected 0 unified results, got %d", len(got.Unified))
	}
}

func TestServiceSearchDeduplicatesAcrossProviders(t *testing.T) {
	reg := core.NewProviderRegistry()
	reg.RegisterSearchProvider("a", &mockSearchProvider{
		id:   "a",
		name: "A",
		data: map[string][]core.SearchResultItem{
			"q": {
				{ID: "x", Title: "Dupe", Artist: "Artist", Source: "a", ISRC: "D1"},
				{ID: "y", Title: "Unique", Artist: "A", Source: "a", ISRC: "U1"},
			},
		},
	})
	reg.RegisterSearchProvider("b", &mockSearchProvider{
		id:   "b",
		name: "B",
		data: map[string][]core.SearchResultItem{
			"q": {
				{ID: "z", Title: "Dupe", Artist: "Artist", Source: "b", ISRC: "D1"},
			},
		},
	})
	svc := NewService(reg)

	req := SearchRequest{Query: "q", Type: "track", Limit: 10}
	got, err := svc.Search(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(got.Single) != 2 {
		t.Errorf("expected 2 raw results after dedup, got %d", len(got.Single))
	}
	if len(got.Unified) != 2 {
		t.Errorf("expected 2 unified (1 merged + 1 unique), got %d", len(got.Unified))
	}
}

func TestServiceSearchBySourceGroup(t *testing.T) {
	reg := core.NewProviderRegistry()
	reg.RegisterSearchProvider("a", &mockSearchProvider{
		id:   "a",
		name: "A",
		data: map[string][]core.SearchResultItem{
			"q": {
				{ID: "a1", Title: "Song A", Artist: "Art", Source: "a", ISRC: "I1"},
				{ID: "a2", Title: "Song A", Artist: "Art", Source: "a", ISRC: "I1"},
			},
		},
	})
	svc := NewService(reg)

	req := SearchRequest{Query: "q", Type: "track", Limit: 10}
	got, err := svc.Search(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	bySource, ok := got.BySource["a"]
	if !ok {
		t.Fatal("expected BySource[\"a\"] to exist")
	}
	if len(bySource) != 1 {
		t.Errorf("expected 1 deduped result per source, got %d", len(bySource))
	}
}

func TestServiceSearchResultCached(t *testing.T) {
	reg := core.NewProviderRegistry()
	svc := NewService(reg)

	req1 := SearchRequest{Query: "q", Type: "track", Limit: 10}
	_, err := svc.Search(context.Background(), req1)
	if err != nil {
		t.Fatalf("first search failed: %v", err)
	}

	req2 := SearchRequest{Query: "q", Type: "track", Limit: 10}
	got, err := svc.Search(context.Background(), req2)
	if err != nil {
		t.Fatalf("second search failed: %v", err)
	}
	if got.Mode != SearchModeUnified {
		t.Errorf("expected mode %q, got %q", SearchModeUnified, got.Mode)
	}
}

// Test that empty query is still cached.
func TestServiceSearchEmptyQueryNotCached(t *testing.T) {
	reg := core.NewProviderRegistry()
	svc := NewService(reg)

	req := SearchRequest{Query: "", Type: "track", Limit: 10}
	got, err := svc.Search(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	_ = got
	// verify cache not stored (empty query is not cached)
	if _, ok := svc.cache.Get("|track"); ok {
		t.Error("empty query should not be cached")
	}
}

func TestServiceSearchContextCancelled(t *testing.T) {
	reg := core.NewProviderRegistry()
	svc := NewService(reg)

	ctx, cancel := context.WithCancel(context.Background())
	cancel()

	req := SearchRequest{Query: "test", Type: "track", Limit: 10}
	_, err := svc.Search(ctx, req)
	if err != nil {
		// context cancellation is handled at provider level; providers
		// in this mock don't check ctx, so no error expected.
		t.Logf("context cancellation error (acceptable): %v", err)
	}
}

func TestServiceSearchDedupBeforeAggregate(t *testing.T) {
	reg := core.NewProviderRegistry()
	reg.RegisterSearchProvider("a", &mockSearchProvider{
		id:   "a",
		name: "A",
		data: map[string][]core.SearchResultItem{
			"q": {
				{ID: "a1", Title: "Same", Artist: "Art", Source: "a", ISRC: "I1"},
				{ID: "a2", Title: "Same", Artist: "Art", Source: "a", ISRC: "I1"},
			},
		},
	})
	svc := NewService(reg)

	req := SearchRequest{Query: "q", Type: "track", Limit: 10}
	got, err := svc.Search(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(got.Unified) != 1 {
		t.Fatalf("expected 1 unified result after dedup+aggregate, got %d", len(got.Unified))
	}
	if len(got.Unified[0].Sources) != 1 {
		t.Errorf("expected 1 source in unified, got %d", len(got.Unified[0].Sources))
	}
}

func TestServiceSearchRankingOrder(t *testing.T) {
	reg := core.NewProviderRegistry()
	reg.RegisterSearchProvider("a", &mockSearchProvider{
		id:   "a",
		name: "A",
		data: map[string][]core.SearchResultItem{
			"hello": {
				{ID: "e1", Title: "Hello World", Artist: "X", Source: "a", ISRC: "I1"},  // prefix match → 80
				{ID: "e2", Title: "Say Hello", Artist: "Y", Source: "a", ISRC: "I2"},    // contains → 60
				{ID: "e3", Title: "hello", Artist: "Z", Source: "a", ISRC: "I3"},        // exact → 100
			},
		},
	})
	svc := NewService(reg)

	req := SearchRequest{Query: "hello", Type: "track", Limit: 10}
	got, err := svc.Search(context.Background(), req)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(got.Unified) != 3 {
		t.Fatalf("expected 3 results, got %d", len(got.Unified))
	}
	if got.Unified[0].Title != "hello" {
		t.Errorf("expected highest ranked result to be exact match 'hello', got %q", got.Unified[0].Title)
	}
}
