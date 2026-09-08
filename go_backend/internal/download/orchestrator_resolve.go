package download

import (
	"sync"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// Per-provider track resolution cache. Key = provider name + a stable identity
// (ISRC, cross-provider ids, or title|artist). This makes the often-slow
// resolve step (amazon showSearch / name searches) run only once per track
// instead of once per provider / repeated play — a general speedup that applies
// to every source.
var (
	resCacheMu    sync.Mutex
	resCache      = map[string]map[string][3]string{}
	resCacheOrder []struct{ provider, key string }
)

const resCacheMaxKeys = 4000

// cachedResolve returns the cached resolution (trackID, title, artist) when
// available; otherwise resolves via resolveProviderTrackID and caches the
// result. Empty [key] disables caching (nothing stable to key on).
func resolucionCacheada(p provider.Provider, name, key string, req Request) (string, string, string) {
	if key != "" {
		resCacheMu.Lock()
		if m, ok := resCache[name]; ok {
			if r, ok2 := m[key]; ok2 {
				resCacheMu.Unlock()
				return r[0], r[1], r[2]
			}
		}
		resCacheMu.Unlock()
	}
	id, title, artist := resolverTrackIDProvider(p, name, req)
	if key != "" && id != "" {
		resCacheMu.Lock()
		if len(resCacheOrder) >= resCacheMaxKeys {
			// Drop the oldest entries so the cache stays bounded.
			for len(resCacheOrder) >= resCacheMaxKeys/2 {
				old := resCacheOrder[0]
				resCacheOrder = resCacheOrder[1:]
				if m, ok := resCache[old.provider]; ok {
					delete(m, old.key)
					if len(m) == 0 {
						delete(resCache, old.provider)
					}
				}
			}
		}
		m := resCache[name]
		if m == nil {
			m = map[string][3]string{}
			resCache[name] = m
		}
		if _, exists := m[key]; !exists {
			m[key] = [3]string{id, title, artist}
			resCacheOrder = append(resCacheOrder, struct{ provider, key string }{name, key})
		}
		resCacheMu.Unlock()
	}
	return id, title, artist
}
