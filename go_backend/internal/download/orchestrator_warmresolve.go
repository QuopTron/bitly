package download

import (
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// warmResolveAndOrder resolves every candidate provider's track id in parallel
// (bounded by a semaphore of 3), waits up to the race window for the preferred
// provider, and returns the reordered try-list: preferred owner first, then
// resolved providers by arrival (fastest first), then unresolved in original
// order.
func (o *Orchestrator) warmResolveAndOrder(providersToTry []string, req Request, lookKey string) []string {
	type warmRes struct {
		name                   string
		trackID, title, artist string
	}
	resCh := make(chan warmRes, len(providersToTry)+1)
	warm := func(name string, pr provider.Provider) {
		id, t, a := resolucionCacheada(pr, name, lookKey, req)
		resCh <- warmRes{name, id, t, a}
	}
	{
		var wg sync.WaitGroup
		sem := make(chan struct{}, 3)
		for _, name := range providersToTry {
			if name == req.Provider && req.Provider == "" {
				continue
			}
			p := o.providers.Get(name)
			if p == nil {
				continue
			}
			if ep, ok := p.(*provider.ExtensionProvider); ok && !ep.DownloadCapable() {
				continue
			}
			if cooldown.IsCooledOp(name, downloadCooldownOp) {
				continue
			}
			wg.Add(1)
			sem <- struct{}{}
			go func(n string, pr provider.Provider) {
				defer wg.Done()
				defer func() { <-sem }()
				warm(n, pr)
			}(name, p)
		}
		go func() {
			wg.Wait()
			close(resCh)
		}()
	}

	// Wait up to the race window for the preferred provider to resolve, while
	// collecting the arrival order of every provider. If the preferred one is
	// slow we already know which fallbacks are ready and can jump straight to
	// them. Anything still resolving keeps running in the background and its
	// result is picked up on a later attempt (it is cached by cachedResolve).
	arrival := []warmRes{}
	resolved := map[string]warmRes{}
	raceDone := false
	deadline := time.Now().Add(raceResolutionTimeout)
	for !raceDone {
		left := time.Until(deadline)
		if left <= 0 {
			raceDone = true
			break
		}
		select {
		case r, ok := <-resCh:
			if !ok {
				raceDone = true
				continue
			}
			arrival = append(arrival, r)
			if r.trackID != "" {
				resolved[r.name] = r
			}
			if r.name == req.Provider && r.trackID != "" {
				raceDone = true
			}
		case <-time.After(left):
			raceDone = true
		}
	}

	// Reorder the try-list: the preferred (owner) provider first when it
	// resolved, then the other resolved providers in arrival order (fastest
	// first), then any still-unresolved candidates in their original order.
	tryOrder := make([]string, 0, len(providersToTry))
	seen := map[string]bool{}
	addTry := func(name string) {
		if name == "" || seen[name] {
			return
		}
		seen[name] = true
		tryOrder = append(tryOrder, name)
	}
	if req.Provider != "" {
		if _, ok := resolved[req.Provider]; ok {
			addTry(req.Provider)
		}
	}
	for _, r := range arrival {
		if r.trackID == "" {
			continue
		}
		if req.Provider != "" && r.name == req.Provider {
			continue
		}
		addTry(r.name)
	}
	for _, name := range providersToTry {
		addTry(name)
	}
	return tryOrder
}

// buildCandidates walks the try-list and keeps only providers that resolved a
// track id for this item, reverse-verifying that a non-owner's id is the
// ORIGINAL requested track. Bounded by maxParallelCandidates and the fallback
// budget (maxFallbackDuration).
