package cache

import "time"

// SearchItem holds a cached search result batch with timestamp.
type SearchItem struct {
	Results   []SearchResult `json:"results"`
	Timestamp time.Time      `json:"timestamp"`
}

// SearchResult represents a single track/album/artist hit from any provider.
type SearchResult struct {
	ID         string `json:"id"`
	Title      string `json:"title"`
	Artist     string `json:"artist"`
	ArtistID   string `json:"artistId"`
	Album      string `json:"album"`
	AlbumID    string `json:"albumId"`
	Duration   int    `json:"durationMs"`
	ISRC       string `json:"isrc"`
	Provider   string `json:"provider"`
	CoverURL   string `json:"coverUrl"`
	TrackType  string `json:"trackType,omitempty"`
}

// SearchCache caches search results per provider+query with TTL.
type SearchCache struct {
	store *Cache[SearchItem]
}

// NewSearchCache creates a search result cache.
// Default cleanup runs every 5 minutes.
func NewSearchCache(ttl time.Duration) *SearchCache {
	return &SearchCache{
		store: New[SearchItem](ttl, 5*time.Minute),
	}
}

// Get returns cached results for a provider+query combination.
func (sc *SearchCache) Get(provider, query string) (SearchItem, bool) {
	return sc.store.Get(provider + "::" + query)
}

// Set stores results for a provider+query combination.
func (sc *SearchCache) Set(provider, query string, item SearchItem) {
	sc.store.Set(provider+"::"+query, item)
}

// Delete removes a cached search.
func (sc *SearchCache) Delete(provider, query string) {
	sc.store.Delete(provider + "::" + query)
}

// Clear removes all cached searches.
func (sc *SearchCache) Clear() {
	sc.store.Clear()
}

// Close stops the background cleanup goroutine.
func (sc *SearchCache) Close() {
	sc.store.Close()
}
