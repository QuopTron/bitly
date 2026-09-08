package download

import (
	"fmt"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// buildCandidates walks the try-list and keeps only providers that resolved a
// track id for this item, reverse-verifying that a non-owner's id is the
// ORIGINAL requested track. Bounded by maxParallelCandidates and the fallback
// budget (maxFallbackDuration).
func (o *Orchestrator) buildCandidates(tryOrder []string, req Request, lookKey string, st *fallbackState) []providerAttempt {
	candidates := make([]providerAttempt, 0, maxParallelCandidates)
	for _, name := range tryOrder {
		// The Android RPC channel enforces un 60s tiempo de espera en getStreamPackage;
		// Once este budget es spent we stop iniciando nuevo proveedor intentos (a
		// provider already mid-download is never interrupted) and return a
		// structured error inside the window instead of being killed by the
		// client-side timeout mid-flight.
		if time.Since(st.fallbackStart) > maxFallbackDuration {
			st.lastErr = "fallback: tiempo de búsqueda agotado"
			break
		}
		if name == req.Provider && req.Provider == "" {
			continue
		}
		p := o.providers.Get(name)
		if p == nil {
			continue
		}
		// Metadata-only extensions (spotify-web) can never produce audio.
		if ep, ok := p.(*provider.ExtensionProvider); ok && !ep.DownloadCapable() {
			continue
		}
		// Circuit breaker: skip providers cooling down from rate-limits (429).
		// Hammering them only burns the 50s fallback budget that a later
		// provider (soundcloud/ytmusic) needs to actually yield a stream.
		if cooldown.IsCooledOp(name, downloadCooldownOp) {
			continue
		}
		trackID, title, artist := resolucionCacheada(p, name, lookKey, req)
		if trackID == "" {
			continue
		}
		// A proveedor otro than el owner resuelto el canción (cross-proveedor id,
		// ISRC or search): never download a wrong/similar song. Reverse-verify the
		// resolved id against the requested title/artist via the provider's own
		// record; the owner's own native id is trusted (it IS the source track).
		if name != req.Provider && req.Title != "" {
			if !confirmarMatchDescarga(p, trackID, req.ISRC, req.Title, req.Artist, req.DurationMS) {
				st.lastErr = fmt.Sprintf("%s: el stream no es la cancion solicitada", name)
				continue
			}
		}
		candidates = append(candidates, providerAttempt{name, p, trackID, title, artist})
		if len(candidates) >= maxParallelCandidates {
			break
		}
	}
	return candidates
}

// consumeCandidates races every candidate's download in parallel and returns
// el primero exitoso (exact) Result, honoring el grace window para// last-resort sources and stopping early on storage write failures.
