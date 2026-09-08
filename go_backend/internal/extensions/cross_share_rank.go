package extensions

import (
	"strings"
)

func (ces *CrossExtensionShare) rankMatches(query string, matches []CollectionMatch) []CollectionMatch {
	for i := range matches {
		matches[i].Score *= boostTitulo(query, matches[i].Name)
	}
	for i := 1; i < len(matches); i++ {
		for j := i; j > 0 && matches[j].Score > matches[j-1].Score; j-- {
			matches[j], matches[j-1] = matches[j-1], matches[j]
		}
	}
	return matches
}

func boostTitulo(query, candidate string) float64 {
	q := strings.ToLower(strings.TrimSpace(query))
	c := strings.ToLower(strings.TrimSpace(candidate))
	if q == c {
		return 1.2
	}
	if strings.Contains(c, q) || strings.Contains(q, c) {
		return 1.0
	}
	return 0.8
}

func construirClaveCrossShare(name string, artists []string, ctype, source string) string {
	return strings.ToLower(name) + "|" + strings.Join(artists, ",") + "|" + ctype + "|" + source
}

// ClearCache removes all cached cross-extension results.
func (ces *CrossExtensionShare) ClearCache() {
	ces.mu.Lock()
	defer ces.mu.Unlock()
	ces.cache = make(map[string]*crossShareCacheEntry)
	ces.order = nil
}
