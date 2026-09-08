package provider

import (
	"github.com/zarz/bitly/go_backend/internal/cooldown"
)

func (p *ExtensionProvider) call(method string, args ...interface{}) (interface{}, error) {
	return p.callOp("", method, args...)
}

// callOp is [call] scoped to an operation class [op] that gets its own
// isolated cooldown bucket:
//   - ""       → provider-wide bucket (playback / search / download fallback);
//   - "feed"   → home-feed requests (getHomeFeed) — a feed endpoint 429ing
//     only cools future feed calls, never playback/search for that provider;
//   - "detail" → raw detail fetches (getAlbum/getArtist/getPlaylist used by
//
// el detail páginas) — mismo isolation, so un tasa-limited detail endpoint//     doesn't disable the provider elsewhere.
//
// Mientras el proveedor es cooling abajo en este bucket el call es omitido rápido// (nil, nil) instead of re-hitting the API. Failed calls whose error mentions
// rate-limit / unavailability / blocked mark the bucket (the 429 errors from
// extension HTTP helpers, e.g. deezer's getJSON throwing "HTTP 429 for ...",
// surface through this path — callers that previously swallowed them with
// `return nil, nil` still trip the breaker, which is what stops hammering).
//
// NOTE: we deliberately do NOT auto-clear the cooldown here on success. A
// provider can have endpoints that still work while its rate-limited endpoints
// 429 (mixed preload traffic); clearing on every success would let the breaker
// flap and never give the API a real break. Recovery is time-based (the window
// simply expires) plus explicit MarkOk from the orchestrator/streaming success
// paths that consumed a real stream/file.
func (p *ExtensionProvider) callOp(op, method string, args ...interface{}) (interface{}, error) {
	if op == "" {
		if cooldown.IsCooled(p.name) {
			return nil, nil
		}
	} else if cooldown.IsCooledOp(p.name, op) {
		return nil, nil
	}
	res, err := p.runtime.CallMethod(p.extID, method, args...)
	if err != nil {
		if op == "" {
			cooldown.MarkError(p.name, err.Error())
		} else {
			cooldown.MarkOpError(p.name, op, err.Error())
		}
		return res, err
	}
	return res, nil
}

// SearchTracks calls the extension's searchTracks(query, limit) JS function.
// Falls back to customSearch with filter "song" ONLY when the extension doesn't
// export searchTracks at all (missing-method). When searchTracks exists but its
// call failed (transport/auth error), the failure is surfaced instead of
// re-running a second full query that will fail the same way — a broken source
// should cost one attempt, not three.
