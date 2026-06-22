package share

import (
	"fmt"
	"sort"
	"strings"
)

func (s *Service) buildCacheKey(name, artists, itemType, sourceExtID string, candidateIDs []string) string {
	keys := make([]string, len(candidateIDs))
	copy(keys, candidateIDs)
	sort.Strings(keys)
	return fmt.Sprintf("%s\x1d%s\x1d%s\x1d%s\x1d%s",
		normalizeLooseTitle(itemType),
		normalizeLooseTitle(name),
		normalizeLooseArtistName(artists),
		sourceExtID,
		strings.Join(keys, "\x1e"),
	)
}

func (s *Service) cacheGet(key string) string {
	if key == "" {
		return ""
	}
	s.cacheMu.RLock()
	defer s.cacheMu.RUnlock()
	return s.cache[key]
}

func (s *Service) cacheSet(key, value string) {
	if key == "" || value == "" {
		return
	}
	s.cacheMu.Lock()
	defer s.cacheMu.Unlock()
	if _, exists := s.cache[key]; !exists {
		s.cacheOrd = append(s.cacheOrd, key)
	}
	s.cache[key] = value
	for len(s.cacheOrd) > maxCacheEntries {
		oldest := s.cacheOrd[0]
		s.cacheOrd = s.cacheOrd[1:]
		delete(s.cache, oldest)
	}
}

func (s *Service) resultsCacheable(results []CrossExtensionShareResult) bool {
	for _, r := range results {
		if r.Found {
			continue
		}
		errText := strings.ToLower(strings.TrimSpace(r.Error))
		if errText == "" ||
			errText == "no results" ||
			errText == "unsupported collection type" ||
			strings.HasSuffix(errText, " not found") ||
			strings.Contains(errText, "found without shareable link") {
			continue
		}
		return false
	}
	return true
}
