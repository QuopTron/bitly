package deezer

import (
	"context"
	"fmt"
	"sync"
	"time"
)

func (c *Client) fetchISRCsParallel(ctx context.Context, tracks []deezerTrack) map[string]string {
	result := make(map[string]string, len(tracks))
	var resultMu sync.Mutex

	var tracksToFetch []deezerTrack
	var directISRCs map[string]string
	c.cacheMu.RLock()
	for _, track := range tracks {
		trackIDStr := fmt.Sprintf("%d", track.ID)
		if track.ISRC != "" {
			result[trackIDStr] = track.ISRC
			if _, ok := c.isrcCache[trackIDStr]; !ok {
				if directISRCs == nil {
					directISRCs = make(map[string]string)
				}
				directISRCs[trackIDStr] = track.ISRC
			}
			continue
		}
		if isrc, ok := c.isrcCache[trackIDStr]; ok {
			result[trackIDStr] = isrc
		} else {
			tracksToFetch = append(tracksToFetch, track)
		}
	}
	c.cacheMu.RUnlock()

	if len(directISRCs) > 0 {
		c.cacheMu.Lock()
		for tid, isrc := range directISRCs {
			c.isrcCache[tid] = isrc
		}
		c.maybeCleanupCachesLocked(time.Now())
		c.cacheMu.Unlock()
	}

	if len(tracksToFetch) == 0 {
		return result
	}

	sem := make(chan struct{}, maxParallelISRC)
	var wg sync.WaitGroup

	for _, track := range tracksToFetch {
		wg.Add(1)
		go func(t deezerTrack) {
			defer wg.Done()
			select {
			case sem <- struct{}{}:
				defer func() { <-sem }()
			case <-ctx.Done():
				return
			}
			trackIDStr := fmt.Sprintf("%d", t.ID)
			fullTrack, err := c.fetchFullTrack(ctx, trackIDStr)
			if err != nil || fullTrack == nil {
				return
			}
			resultMu.Lock()
			result[trackIDStr] = fullTrack.ISRC
			resultMu.Unlock()
			c.cacheMu.Lock()
			c.isrcCache[trackIDStr] = fullTrack.ISRC
			c.maybeCleanupCachesLocked(time.Now())
			c.cacheMu.Unlock()
		}(track)
	}
	wg.Wait()
	return result
}
