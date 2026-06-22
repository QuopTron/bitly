package deezer

import "time"

func (c *Client) pruneExpiredCacheEntriesLocked(cache map[string]*cacheEntry, now time.Time) {
	for key, entry := range cache {
		if entry == nil || now.After(entry.expiresAt) {
			delete(cache, key)
		}
	}
}

func (c *Client) trimCacheEntriesLocked(cache map[string]*cacheEntry, maxEntries int) {
	if maxEntries <= 0 || len(cache) <= maxEntries {
		return
	}
	for len(cache) > maxEntries {
		var oldestKey string
		var oldestExpiry time.Time
		first := true
		for key, entry := range cache {
			expiry := time.Time{}
			if entry != nil {
				expiry = entry.expiresAt
			}
			if first || expiry.Before(oldestExpiry) {
				first = false
				oldestKey = key
				oldestExpiry = expiry
			}
		}
		if oldestKey == "" {
			return
		}
		delete(cache, oldestKey)
	}
}

func (c *Client) trimStringCacheEntriesLocked(cache map[string]string, maxEntries int) {
	if maxEntries <= 0 || len(cache) <= maxEntries {
		return
	}
	toRemove := len(cache) - maxEntries
	for key := range cache {
		delete(cache, key)
		toRemove--
		if toRemove <= 0 {
			return
		}
	}
}

func (c *Client) maybeCleanupCachesLocked(now time.Time) {
	periodicCleanupDue := c.cacheCleanupInterval > 0 &&
		(c.lastCacheCleanup.IsZero() || now.Sub(c.lastCacheCleanup) >= c.cacheCleanupInterval)

	if periodicCleanupDue {
		c.pruneExpiredCacheEntriesLocked(c.searchCache, now)
		c.pruneExpiredCacheEntriesLocked(c.albumCache, now)
		c.pruneExpiredCacheEntriesLocked(c.artistCache, now)
		c.lastCacheCleanup = now
	}

	if len(c.searchCache) > maxSearchCacheEntries {
		if !periodicCleanupDue {
			c.pruneExpiredCacheEntriesLocked(c.searchCache, now)
		}
		c.trimCacheEntriesLocked(c.searchCache, maxSearchCacheEntries)
	}
	if len(c.albumCache) > maxAlbumCacheEntries {
		if !periodicCleanupDue {
			c.pruneExpiredCacheEntriesLocked(c.albumCache, now)
		}
		c.trimCacheEntriesLocked(c.albumCache, maxAlbumCacheEntries)
	}
	if len(c.artistCache) > maxArtistCacheEntries {
		if !periodicCleanupDue {
			c.pruneExpiredCacheEntriesLocked(c.artistCache, now)
		}
		c.trimCacheEntriesLocked(c.artistCache, maxArtistCacheEntries)
	}
	if len(c.isrcCache) > maxISRCCacheEntries {
		c.trimStringCacheEntriesLocked(c.isrcCache, maxISRCCacheEntries)
	}
}
