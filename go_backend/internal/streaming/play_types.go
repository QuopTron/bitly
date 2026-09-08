package streaming

import (
	"strings"

	"github.com/zarz/bitly/go_backend/internal/lyrics"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

type StreamPackage struct {
	AudioURL string                `json:"audioUrl"`
	VideoURL string                `json:"videoUrl,omitempty"`
	Provider string                `json:"provider"`
	Quality  string                `json:"quality"`
	Track    *provider.TrackResult `json:"track"`
	Lyrics   *lyrics.Lyrics        `json:"lyrics,omitempty"`
}

// streamingProviders can serve actual audio streams. Includes both native
// names and their bundled -web extension equivalents: after extensions load,
// qobuz/tidal/etc. register under "qobuz-web"/"tidal-web" (and apple-music,
// amazon), so the hardcoded native names alone would silently skip real
// sources during rescue. Order mirrors SpotiFLAC: exact sources (deezer,
// qobuz, tidal, amazon — resolve the same track via ISRC) before soundcloud's
// loose name-search.
var streamingProviders = []string{
	"youtube", "deezer", "qobuz", "tidal", "qobuz-web", "tidal-web", "amazon",
	"ytmusic-spotiflac", "apple-music", "spotify-web", "soundcloud",
}

// isPlayableStreamProvider returns true if the provider can stream audio.
func esProviderStreaming(name string) bool {
	for _, p := range streamingProviders {
		if p == name {
			return true
		}
	}
	return false
}

// isPlayableStreamURL reports whether a resolved "stream URL" is actually
// streamable by the player. Some providers (amazon/qobuz DRM) return a local
// path to an encrypted file instead of an http stream — media_kit cannot decode
// that and would loop "Error decoding audio". Only http(s) URLs are playable.
func esURLReproducible(u string) bool {
	return strings.HasPrefix(u, "http://") || strings.HasPrefix(u, "https://")
}

// fullStreamProviders yield full-length http streams. The fast-play path should
// only be served from these; preview-prone providers (apple-music, spotify-web)
// return 30s audio clips that would cut playback short, so playback for those
// goes straight to the produced download instead.
//
// deezer/qobuz-web/tidal-web are included because their extensions now export a
// real getDownloadUrl that resolves the Zarz download descriptor and returns
// El plain http audio URL solo cuando el stream necesita sin cliente-side// decryption (Deezer lossy tiers, Qobuz direct files, TIDAL "direct" kind).
// Without a verified session they fail fast (null) and the flow falls through
// to the download pipeline, which performs any required decryption.
var fullStreamProviders = []string{
	"youtube", "ytmusic-spotiflac", "soundcloud", "deezer",
	"qobuz-web", "tidal-web",
}

// IsFullStreamProvider reports whether [name] can serve a full-length stream
// (as opposed to a 30s preview).
func IsFullStreamProvider(name string) bool {
	for _, p := range fullStreamProviders {
		if p == name {
			return true
		}
	}
	return false
}

// trimKnownPrefix strips an "<provider>:" id prefix (feed items carry ids like
// "amazon:abc" that extensions don't understand).
func quitarPrefijoConocido(id string) string {
	if i := strings.Index(id, ":"); i > 0 {
		return id[i+1:]
	}
	return id
}

// StreamQuick resolves a playable direct stream for a track using its
// cross-provider identifiers (spotify/deezer/tidal/qobuz ids + ISRC) via
// CheckAvailability instead of slow name searches — the same route the download
// orchestrator uses. When a real http stream exists it is found in ~1-2s, so
// playback can begin immediately; providers that only expose 30s previews or
// DRM files fail fast so the caller falls through to the cached, identifier-based
// download. Returns (url, provider, err).
//
// The resuelto id es NEVER trusted blindly: cuando se wasn't obtained de an// authoritative identifier (ISRC / cross-provider id), it is verified against
// el consulta title/artista so un wrong/similar canción (e.g. otro feed's id fed a// Un completo-stream proveedor) es nunca served — reproducción falls un través de en su lugar.
