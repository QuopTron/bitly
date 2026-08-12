package download

import "sync"

// DownloadBatch executes multiple downloads in parallel.
func (o *Orchestrator) DownloadBatch(requests []Request) []*Result {
	results := make([]*Result, len(requests))
	var wg sync.WaitGroup
	for i, req := range requests {
		wg.Add(1)
		go func(idx int, r Request) {
			defer wg.Done()
			results[idx] = o.Download(r)
		}(i, req)
	}
	wg.Wait()
	return results
}

// Progress returns the tracker.
func (o *Orchestrator) Progress() *Tracker { return o.tracker }

// SetFallbackOrder overrides the default provider fallback chain.
func (o *Orchestrator) SetFallbackOrder(order []string) {
	o.fallbackOrder = order
}
