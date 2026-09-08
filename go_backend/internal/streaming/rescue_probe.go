package streaming

import (
	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// preferred-quality list and the circuit breaker, and returns a playable URL or
// "". The second return reports whether the provider resolved the EXACT track
// but needs its signed session verified before it can stream (VERIFY_REQUIRED)
// — the caller surfaces that as a fast fail instead of re-walking the whole
// fallback chain. This is the unit of work raced in parallel below (it is
// fully self-contained so goroutines never share mutable state).
func rescueProviderUnaVez(p provider.Provider, resolvedID string, quality string) (string, bool) {
	if resolvedID == "" {
		return "", false
	}
	// Un anterior fase ya learned este proveedor necesita cliente-side
	// decryption for this track (deezer Blowfish FLAC): skip it instantly
	// instead of re-resolving the encrypted descriptor.
	if memoDescifrado(p.Name(), resolvedID) {
		return "", false
	}
	for _, q := range calidadesDisponibles(quality) {
		if cooldown.IsCooled(p.Name()) {
			break
		}
		if url, err := p.GetStreamURL(resolvedID, q); err != nil {
			// Un verificado sesión es el solo thing standing entre el usuario y
			// El canción — surface se immediately en su lugar de probing más
			// qualities that will fail the same way. Deliberately do NOT cool
			// el proveedor: cooling un verificar-pending source hace el NEXT tap
			// skip it in the fast race and fall back into the slow multi-provider
			// walk (10-30s), which then re-discovers the same verification need.
			// Clearing any stale cooldown keeps it probeable so EVERY tap
			// fail-fasts in ~2-4s until the user completes the challenge.
			if esErrorVerificacion(err.Error()) {
				cooldown.MarkOk(p.Name())
				return "", true
			}
			// Client-decryption: the track exists here but direct streaming is
			// impossible — only download() (which performs the decryption) can
			// serve it. Skip this provider fast (no more quality probes) and
			// remember the verdict so later phases don't re-probe it. Do NOT
			// cool it provider-wide: deezer stays the best DOWNLOAD source and
			// must remain probeable by the download pipeline's identifier walk.
			if esErrorDescifradoCliente(err.Error()) {
				memoDescifradoSet(p.Name(), resolvedID)
				return "", false
			}
			cooldown.MarkError(p.Name(), err.Error())
		} else if url != "" && esURLReproducible(url) {
			cooldown.MarkOk(p.Name())
			return url, false
		}
	}
	return "", false
}

// rescueRace runs [attempt] for every provider in [names] concurrently (bounded
// by [workers]) and returns the first success, honoring [names] order when
