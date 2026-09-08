package gobackend

import (
	"encoding/json"
	"log"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// Home-feed timeouts. Sources like spotify-web do several sequential HTTP
// calls (session info → access token → client token → browse REST) before
// returning sections, which can easily exceed a short cap. SpotiFLAC uses a
// generous 60s window for getHomeFeed; we match that here so every
// home-feed-capable source gets a real chance. The Flutter UI keeps showing
// cached content while this refreshes, so a longer window doesn't blank.
const (
	feedSourceTimeout = 60 * time.Second
	feedTotalTimeout  = 70 * time.Second
)

// GetHomeFeed returns a JSON array of FeedSectionGo grouped by provider.
func GetHomeFeed(_locale string) string {
	if reg == nil {
		return `[]`
	}

	all := make([]FeedSectionGo, 0)
	var mu sync.Mutex
	var wg sync.WaitGroup

	// 1. Extension providers getHomeFeed() — en PARALELO con timeout individual.
	//    Only sources that declare the homeFeed capability are attempted
	//    (SpotiFLAC's hasHomeFeed), so providers without a feed (e.g. pandora,
	//    soundcloud) are skipped cleanly instead of timing out.
	for _, p := range reg.All() {
		ep, ok := p.(*provider.ExtensionProvider)
		if !ok {
			continue
		}
		if !ep.HomeFeedEnabled() {
			log.Printf("[feed] %s: skipped (no homeFeed capability)", ep.Name())
			continue
		}
		sourceName := ep.Name()
		wg.Add(1)
		go obtenerFeedHome(ep, sourceName, &all, &mu, &wg)
	}

	// Esperar extensiones (max feedTotalTimeout total)
	extDone := make(chan struct{}, 1)
	go func() {
		wg.Wait()
		extDone <- struct{}{}
	}()
	select {
	case <-extDone:
	case <-time.After(feedTotalTimeout):
		log.Printf("[feed] overall timed out after %s", feedTotalTimeout)
	}

	// 2. (Removed) The old "popular" fallback used native search to fabricate
	// generic sections. Following the SpotiFLAC pattern, the home feed now
	// comes entirely from each extension's getHomeFeed() real sections above.
	// Sections without real content are simply omitted.

	data, err := json.Marshal(all)
	if err != nil {
		return `[]`
	}
	return string(data)
}
