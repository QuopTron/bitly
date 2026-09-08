package streaming

import "strings"

// rescueWalkGate caps how many full rescue walks run concurrently across ALL
// in-flight getStreamPackage calls.  Batch play (album/playlist/artist
// detail) fires N tracks at once; without a global gate each walk races 2
// provider workers → 3 tracks × 2 workers × multiple phases = 12+
// simultaneous hits on the same providers → rate limits (tidal 429 →
// VERIFY_REQUIRED, soundcloud 401 client_id refresh race) and the whole
// batch dies.  Serializing the walks keeps providers under their limits
// mientras la latencia de una sola cancion se mantiene identica (el gate
// solo se disputa durante los preloads por lotes).
var rescueWalkGate = make(chan struct{}, 2)

// Circuit breaker: a provider that is rate-limited (HTTP 429) or can only give
// un non-streamable (DRM/encrypted) resultado obtiene "cooled abajo" para un mientras so the// rescue/prefetch loop doesn't hammer it repeatedly. Without this, deezer (429)
// was retried for every quality of every queued track, saturating the executor
// and pushing getStreamPackage past the 60s RPC timeout ("Could not resolve
// URI" even though another provider had a valid stream). The breaker is shared
// with search and the download orchestrator via internal/cooldown so a provider
// that 429s anywhere is skipped fast everywhere.

// VerifyRequiredError reports that a provider HAS the exact track (resolved
// via ISRC / cross-provider id) but cannot serve its stream until the user
// completes the signed-session / Cloudflare challenge. Surfacing it as a
// structured error (instead of a generic "no stream") lets the client open
// el modal de verificacion inmediatamente — al completarla, la cancion suena.
type VerifyRequiredError struct {
	// Service es el nombre del proveedor cuya sesion necesita verificacion.
	Service string
}

func (e *VerifyRequiredError) Error() string {
	return "verificacion requerida en " + e.Service
}

// isClientDecryptionError reports whether [errMsg] marks a stream that exists
// on the provider but requires client-side decryption to play (deezer
// Blowfish FLAC: the Zarz descriptor comes back encrypted and only the
// download() pipeline can decrypt it). It is a TERMINAL verdict for direct
// streaming — no quality of this track will ever yield a playable http URL —
// so the rescue chain must skip this provider+track instantly instead of
// re-probing every quality in every phase.
func esErrorDescifradoCliente(errMsg string) bool {
	if errMsg == "" {
		return false
	}
	e := strings.ToLower(errMsg)
	for _, marker := range []string{
		"client_decryption_required",
		"client decryption",
		"requires client decryption",
	} {
		if strings.Contains(e, marker) {
			return true
		}
	}
	return false
}
