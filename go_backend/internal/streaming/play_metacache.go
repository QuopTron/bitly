package streaming

import (
	"strings"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

var (
	metaMu    sync.Mutex
	metaCache = map[string]cacheEntry{}
)

type cacheEntry struct {
	track *provider.TrackResult
	at    time.Time
}

const metaCacheTTL = 15 * time.Minute

// metadataCacheKey builds a stable identity for a track resolution: the
// strongest identifier present wins — ISRC (same song on every provider),
// then a cross-provider id / native track id, then normalized title|artist.
func claveCacheMetadata(isrc, spotifyID, deezerID, tidalID, qobuzID, trackID, trackName, artistName string) string {
	for _, id := range []string{isrc, spotifyID, deezerID, tidalID, qobuzID, trackID} {
		id = strings.TrimSpace(id)
		if id != "" && id != "null" {
			return "id:" + strings.ToUpper(id)
		}
	}
	q := strings.ToLower(strings.TrimSpace(trackName + "|" + artistName))
	if q == "" || q == "|" {
		return ""
	}
	return "n:" + q
}

func metadataCacheada(key string) *provider.TrackResult {
	if key == "" {
		return nil
	}
	metaMu.Lock()
	defer metaMu.Unlock()
	if e, ok := metaCache[key]; ok {
		if time.Since(e.at) < metaCacheTTL {
			return e.track
		}
		delete(metaCache, key)
	}
	return nil
}

func guardarMetadata(key string, t *provider.TrackResult) {
	if key == "" || t == nil {
		return
	}
	metaMu.Lock()
	defer metaMu.Unlock()
	if len(metaCache) > 1200 {
		for k, e := range metaCache {
			if time.Since(e.at) > metaCacheTTL/2 {
				delete(metaCache, k)
			}
		}
	}
	metaCache[key] = cacheEntry{track: t, at: time.Now()}
}

// fetchMetadata obtiene metadata del track desde cualquier provider.
// Estrategia anti-429: resuelve por ISRC/ids exactos ANTES de cualquier
// name-search (y solo si el provider está sano), cachea por identidad estable
// (ISRC/ids/título+artista), y respeta el circuit-breaker — un provider en
// cooldown se salta, nunca se le hace name-search.
