package download

import (
	"strings"
	"sync"
	"time"
)

// consumeCandidates races every candidate's download in parallel and returns
// el primero exitoso (exact) Result, honoring el grace window para// last-resort sources and stopping early on storage write failures.
func (o *Orchestrator) consumeCandidates(candidates []providerAttempt, req Request, outDir string, st *fallbackState) *Result {
	outCh := make(chan *Result, len(candidates))
	var wg sync.WaitGroup
	semDl := make(chan struct{}, maxParallelDownloads)
	for _, c := range candidates {
		wg.Add(1)
		go func(c providerAttempt) {
			defer wg.Done()
			semDl <- struct{}{}
			defer func() { <-semDl }()
			outCh <- o.attemptDownload(req, c.name, c.p, c.trackID, c.title, c.artist, outDir)
		}(c)
	}
	allDone := make(chan struct{})
	go func() { wg.Wait(); close(allDone) }()

	// A último-resort proveedor (soundcloud/youtube name-búsqueda) es pequeño y
	// finishes first, but it can be a wrong/similar upload of the song. So
	// el FIRST finishing proveedor does sin automatically win: un exact
	// (lossless/identifier-resolving) source lands immediately, while a
	// last-resort source must wait a short grace window for an exact
	// companion (still in flight) to land the real original. Only when no
	// exact candidate remains in flight, or the grace elapses, is the
	// last-resort source accepted — so the common "original wins" case stays
	// fast while remixes are rejected as the default.
	exactInFlight := 0
	for _, c := range candidates {
		if !esProviderUltimoRecurso(c.name) {
			exactInFlight++
		}
	}
	var lastResort *Result
	var graceCh <-chan time.Time
	var graceTimer *time.Timer
consume:
	for {
		select {
		case res, ok := <-outCh:
			if !ok {
				break consume
			}
			if res == nil {
				continue
			}
			if res.Success {
				if !esProviderUltimoRecurso(res.Provider) {
					return res
				}
				if lastResort == nil {
					lastResort = res
					graceTimer = time.NewTimer(authorityGrace)
					graceCh = graceTimer.C
				}
				continue
			}
			if res.Error != "" {
				st.lastErr = res.Error
				// A verificación-required failure es el la mayoría actionable outcome
				// (the provider HAS the track, only its signed session needs
				// refreshing): remember it and don't let a later generic error
				// from another provider overwrite the signal below.
				if res.ErrorType == "verification_required" ||
					clasificarErrorVerificacion(res.Error) != "" {
					st.verificationSeen = true
				}
			}
			if res.Service != "" {
				st.verificationService = res.Service
			}
			if strings.Contains(res.Error, "encriptado") {
				st.encryptedSeen = true
			}
			// Storage write failures (no space, permission denied, read-only fs)
			// mean the file cannot be written regardless of the provider — stop
			// el respaldo loop immediately en su lugar de wasting el remaining
			// budget on providers that will all fail the same way.
			if esFalloEscrituraAlmacenamiento(res.Error) {
				if graceTimer != nil {
					graceTimer.Stop()
				}
				return res
			}
			if !esProviderUltimoRecurso(res.Provider) {
				exactInFlight--
				if exactInFlight == 0 && lastResort != nil {
					if graceTimer != nil {
						graceTimer.Stop()
					}
					return lastResort
				}
			}
		case <-allDone:
			if lastResort != nil {
				if graceTimer != nil {
					graceTimer.Stop()
				}
				return lastResort
			}
			break consume
		case <-graceCh:
			if graceTimer != nil {
				graceTimer.Stop()
			}
			return lastResort
		}
	}
	return nil
}
