package download

import (
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// preferredStreamOrder lists streaming providers best-first. It includes the
// extension-registered (-web) names because the native providers they replace
// (qobuz/tidal/apple/spotify) are never registered — using the native names
// would silently skip real sources during fallback.
//
// Order mirrors the SpotiFLAC middleware: pick the EXACT source first (amazon /
// deezer / qobuz / tidal resolve the same track via ISRC + SongLink). When
// those are unavailable (rate-limited/cold), fall back to YouTube (ytmusic)
// whose audio is the actual song, and leave soundcloud's loose name-search —
// which can pull a same-title remix — for last.
var preferredStreamOrder = []string{
	"amazon", "deezer", "qobuz-web", "tidal-web",
	"youtube", "ytmusic-spotiflac", "pandora",
	"soundcloud", "apple-music", "spotify-web",
}

// buildFallbackOrder derives the fallback order from the providers actually
// registered, preferring [priority] (best-first) and appending any remaining
// streaming-capable providers. Metadata-only providers (musicbrainz, and
// extensions without a download capability) are excluded.
func construirOrdenFallback(reg *provider.Registry, priority []string) []string {
	var order []string
	seen := map[string]bool{}
	// Native-only non-streamers that may still be registered.
	neverStream := map[string]bool{
		"musicbrainz": true,
		"spotify":     true,
		"apple":       true,
	}
	for _, name := range priority {
		p := reg.Get(name)
		if p == nil || neverStream[name] {
			continue
		}
		if ep, ok := p.(*provider.ExtensionProvider); ok && !ep.DownloadCapable() {
			continue
		}
		order = append(order, name)
		seen[name] = true
	}
	// Any remaining streaming-capable providers not in the preferred list.
	for _, name := range reg.Names() {
		if seen[name] || neverStream[name] {
			continue
		}
		p := reg.Get(name)
		if ep, ok := p.(*provider.ExtensionProvider); ok && !ep.DownloadCapable() {
			continue
		}
		order = append(order, name)
	}
	return order
}
