package streaming

import (
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/lyrics"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// StreamPackage is the complete result for playing a track.
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
func isStreamingProvider(name string) bool {
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
func isPlayableStreamURL(u string) bool {
	return strings.HasPrefix(u, "http://") || strings.HasPrefix(u, "https://")
}

// fullStreamProviders yield full-length http streams. The fast-play path should
// only be served from these; preview-prone providers (apple-music, spotify-web)
// return 30s audio clips that would cut playback short, so playback for those
// goes straight to the produced download instead.
var fullStreamProviders = []string{"youtube", "ytmusic-spotiflac", "soundcloud", "deezer"}

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
func trimKnownPrefix(id string) string {
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
// The resolved id is NEVER trusted blindly: when it wasn't obtained from an
// authoritative identifier (ISRC / cross-provider id), it is verified against
// the query title/artist so a wrong/similar track (e.g. another feed's id fed to
// a full-stream provider) is never served — playback falls through instead.
func StreamQuick(
	reg *provider.Registry,
	providerName, trackID, quality, isrc, spotifyID, deezerID, tidalID, qobuzID string,
	trackName, artistName string,
) (string, string, error) {
	if reg == nil {
		return "", "", fmt.Errorf("no inicializado")
	}
	if providerName == "" {
		return "", "", fmt.Errorf("sin proveedor")
	}
	p := reg.Get(providerName)
	if p == nil {
		return "", "", fmt.Errorf("proveedor no encontrado: %s", providerName)
	}
	// Authoritative identifiers resolve the EXACT track; a plain trackID (often
	// another provider's native id) does not and must be verified later.
	authoritative := isrc != "" || spotifyID != "" || deezerID != "" || tidalID != "" || qobuzID != ""
	id := ""
	if ep, ok := p.(*provider.ExtensionProvider); ok {
		if foundID, found := ep.CheckAvailability(isrc, trackName, artistName, spotifyID, deezerID, tidalID, qobuzID, 0); found && foundID != "" {
			id = foundID
		}
	}
	if id == "" && isrc != "" {
		if t, err := p.GetTrackByISRC(isrc); err == nil && t != nil && t.ID != "" {
			id = t.ID
		}
	}
	if id == "" {
		id = trimKnownPrefix(trackID)
		authoritative = false
	}
	if id == "" {
		return "", "", fmt.Errorf("no se pudo identificar el track en %s", providerName)
	}
	// Always verify the resolved id really is the requested track when we have
	// its title — even when the id came from an "authoritative" identifier (a
	// wrong/misreported ISRC or a cross-provider id still produces a wrong song,
	// which is worse than a moment's extra lookup). We never play a similar song.
	if trackName != "" {
		id = verifyStreamMatch(p, id, trackName, artistName, isrc, authoritative)
		if id == "" {
			return "", "", fmt.Errorf("no se pudo confirmar la cancion original en %s", providerName)
		}
	}
	for _, q := range availableQualities(quality) {
		if cooldown.IsCooled(providerName) {
			break
		}
		url, err := p.GetStreamURL(id, q)
		if err != nil {
			cooldown.MarkError(providerName, err.Error())
			continue
		}
		if url != "" && isPlayableStreamURL(url) {
			cooldown.MarkOk(providerName)
			return url, providerName, nil
		}
	}
	return "", "", fmt.Errorf("sin stream reproducible en %s", providerName)
}

// verifyStreamMatch confirms that a resolved id actually maps back to the
// ORIGINAL query track before its stream is served. It returns [id] unchanged
// when confident, or "" when it cannot be confirmed — so the caller falls
// through to a path with stricter matching instead of playing a wrong/similar
// song (remix/live/cover/other track). [isrc] is the ISRC the caller was given
// (may be empty); [authoritative] reports whether [id] came from an ISRC or a
// cross-provider id (trusted if it can't be fetched) as opposed to a guessed
// id (refused if it can't be fetched).
func verifyStreamMatch(p provider.Provider, id, queryTitle, queryArtist, isrc string, authoritative bool) string {
	if queryTitle == "" {
		return id
	}
	t, err := p.GetTrack(id)
	if err != nil || t == nil {
		// Can't fetch the record to verify: only an authoritative identifier is
		// trusted; a guessed id is refused rather than guessing a wrong song.
		if authoritative {
			return id
		}
		return ""
	}
	// ISRC mismatch is the strongest, cheapest mismatch signal: when both sides
	// carry an ISRC and they differ, it is definitely not the requested track.
	if isrc != "" && t.ISRC != "" && !strings.EqualFold(strings.ToUpper(isrc), strings.ToUpper(t.ISRC)) {
		return ""
	}
	if _, ok := provider.OriginalStrength(queryTitle, queryArtist, *t); ok {
		return id
	}
	// The provider's own record may expose an ISRC: re-resolving through the
	// same provider's ISRC route is another way to confirm identity.
	if t.ISRC != "" {
		if it, err := p.GetTrackByISRC(t.ISRC); err == nil && it != nil {
			if _, ok := provider.OriginalStrength(queryTitle, queryArtist, *it); ok {
				return id
			}
		}
	}
	return ""
}

// GetStreamPackage busca metadata + stream URL + letras en una sola llamada.
// [isrc] + cross-provider ids (spotify/deezer/tidal/qobuz) let the resolution
// identify the track EXACTLY (ISRC / CheckAvailability) instead of name-searching
// every provider — the single biggest driver of provider rate-limits (429) was
// repeated per-track name searches during prefetch/queue traversal.
func GetStreamPackage(
	reg *provider.Registry,
	lyricsClient *lyrics.Client,
	preferredProvider, trackID, quality string,
	fetchLyrics bool, trackName, artistName, isrc, spotifyID, deezerID, tidalID, qobuzID string,
) (*StreamPackage, error) {
	if reg == nil {
		return nil, fmt.Errorf("no inicializado")
	}
	if quality == "" {
		quality = "FLAC"
	}

	track := fetchMetadata(reg, preferredProvider, trackID, trackName, artistName, isrc, spotifyID, deezerID, tidalID, qobuzID)
	if track != nil {
		if trackName == "" {
			trackName = track.Title
		}
		if artistName == "" {
			artistName = track.Artist
		}
	}

	streamURL := ""
	streamProvider := ""
	if preferredProvider != "" && isStreamingProvider(preferredProvider) {
		url, err := tryStream(reg, preferredProvider, trackID, track, quality)
		if err == nil && url != "" {
			streamURL = url
			streamProvider = preferredProvider
		}
	}

	if streamURL == "" {
		url, prov, attempted := rescueStream(reg, track, trackName, artistName, quality)
		if url != "" {
			streamURL = url
			streamProvider = prov
		} else if len(attempted) > 0 {
			return nil, fmt.Errorf("no se encontro stream en: %s", strings.Join(attempted, ", "))
		}
	}

	if streamURL == "" {
		return nil, fmt.Errorf("no se encontro stream en ningun proveedor")
	}

	// Reject a non-playable result (local path to an encrypted/DRM file) so the
	// player never loops "Error decoding audio"; only http(s) URLs stream.
	if !isPlayableStreamURL(streamURL) {
		return nil, fmt.Errorf("stream no reproducible en %s (encriptado)", streamProvider)
	}

	pkg := &StreamPackage{
		AudioURL: streamURL,
		Provider: streamProvider,
		Quality:  quality,
	}

	if track != nil {
		pkg.Track = track
	} else if trackName != "" && artistName != "" {
		p := reg.Get(streamProvider)
		if p != nil {
			if results, _ := p.SearchTracks(trackName+" "+artistName, 8); len(results) > 0 {
				if best := provider.BestOriginal(trackName, artistName, results); best != nil {
					pkg.Track = best
				}
			}
		}
	}

	if fetchLyrics && lyricsClient != nil && trackName != "" && artistName != "" {
		lyr, err := lyricsClient.GetLyrics(trackName, artistName, 0)
		if err == nil && lyr != nil {
			pkg.Lyrics = lyr
		}
	}

	return pkg, nil
}

// metadata by identity across the noisiest per-track requests. It is a plain
// LRU/TTL map keyed by the feed track's stable identity so repeated
// resolutions (prefetch on every screen, queue neighbours, re-taps) resolve the
// FIRST time and then serve the cached track — instead of name-searching every
// provider again per request, which is what burned provider rate limits (429)
// during long browsing sessions.
var (
	metaMu    sync.Mutex
	metaCache = map[string]cacheEntry{}
)

type cacheEntry struct {
	track *provider.TrackResult
	at    time.Time
}

const metaCacheTTL = 15 * time.Minute

// metadataCacheKey builds a stable identity for a track resolution: the
// strongest identifier present wins — ISRC (same song on every provider),
// then a cross-provider id / native track id, then normalized title|artist.
func metadataCacheKey(isrc, spotifyID, deezerID, tidalID, qobuzID, trackID, trackName, artistName string) string {
	for _, id := range []string{isrc, spotifyID, deezerID, tidalID, qobuzID, trackID} {
		id = strings.TrimSpace(id)
		if id != "" && id != "null" {
			return "id:" + strings.ToUpper(id)
		}
	}
	q := strings.ToLower(strings.TrimSpace(trackName + "|" + artistName))
	if q == "" || q == "|" {
		return ""
	}
	return "n:" + q
}

func metaCached(key string) *provider.TrackResult {
	if key == "" {
		return nil
	}
	metaMu.Lock()
	defer metaMu.Unlock()
	if e, ok := metaCache[key]; ok {
		if time.Since(e.at) < metaCacheTTL {
			return e.track
		}
		delete(metaCache, key)
	}
	return nil
}

func metaStore(key string, t *provider.TrackResult) {
	if key == "" || t == nil {
		return
	}
	metaMu.Lock()
	defer metaMu.Unlock()
	if len(metaCache) > 1200 {
		for k, e := range metaCache {
			if time.Since(e.at) > metaCacheTTL/2 {
				delete(metaCache, k)
			}
		}
	}
	metaCache[key] = cacheEntry{track: t, at: time.Now()}
}

// fetchMetadata obtiene metadata del track desde cualquier provider.
// Estrategia anti-429: resuelve por ISRC/ids exactos ANTES de cualquier
// name-search (y solo si el provider está sano), cachea por identidad estable
// (ISRC/ids/título+artista), y respeta el circuit-breaker — un provider en
// cooldown se salta, nunca se le hace name-search.
func fetchMetadata(reg *provider.Registry, providerName, trackID, trackName, artistName, isrc, spotifyID, deezerID, tidalID, qobuzID string) *provider.TrackResult {
	cacheKey := metadataCacheKey(isrc, spotifyID, deezerID, tidalID, qobuzID, trackID, trackName, artistName)
	// Session cache: the same track is resolved many times (feed prefetch,
	// queue neighbours, re-tap). Serve the cached result instead of re-searching.
	if cached := metaCached(cacheKey); cached != nil {
		return cached
	}

	store := func(t *provider.TrackResult) *provider.TrackResult {
		metaStore(cacheKey, t)
		// Also index by the found track's ISRC so later calls that only carry a
		// different provider id still hit (their key normalizes to the ISRC).
		if t != nil && t.ISRC != "" {
			metaStore(metadataCacheKey(t.ISRC, "", "", "", "", "", "", ""), t)
		}
		return t
	}

	exactID := trimKnownPrefix(trackID)
	if providerName != "" {
		p := reg.Get(providerName)
		if p != nil && !cooldown.IsCooled(providerName) {
			// Exact ISRC first — one call, no name search, and the result is the
			// canonical identity every provider can resolve against.
			if isrc != "" {
				if track, err := p.GetTrackByISRC(isrc); err == nil && track != nil {
					return store(track)
				}
			}
			if exactID != "" {
				if track, err := p.GetTrack(exactID); err == nil && track != nil {
					return store(track)
				}
			}
			// Cross-provider ids via the provider that owns them (only the
			// matching shape is fed, so no wasted calls).
			for _, cid := range []struct {
				name string
				id   string
			}{{"spotify", spotifyID}, {"deezer", deezerID}, {"tidal", tidalID}, {"qobuz", qobuzID}} {
				if cid.id == "" || cid.name == providerName {
					continue
				}
				if t, err := p.GetTrack(cid.id); err == nil && t != nil {
					return store(t)
				}
			}
			if trackName != "" && artistName != "" {
				if results, err := p.SearchTracks(trackName+" "+artistName, 8); err == nil && len(results) > 0 {
					if best := provider.BestOriginal(trackName, artistName, results); best != nil {
						return store(best)
					}
				}
			}
		}
	}

	// No exact id on the preferred provider: try the ISRC on the OTHER
	// streaming providers (each may know it natively), skipping cooled ones.
	if isrc != "" {
		for _, name := range streamingProviders {
			if name == providerName {
				continue
			}
			p := reg.Get(name)
			if p == nil || cooldown.IsCooled(name) {
				continue
			}
			if track, err := p.GetTrackByISRC(isrc); err == nil && track != nil {
				return store(track)
			}
		}
	}

	// Last resort — bounded name search across healthy providers, only when no
	// identifier exists to resolve exactly.
	if trackName != "" && artistName != "" {
		for _, name := range streamingProviders {
			if name == providerName {
				continue
			}
			p := reg.Get(name)
			if p == nil || cooldown.IsCooled(name) {
				continue
			}
			if results, err := p.SearchTracks(trackName+" "+artistName, 8); err == nil && len(results) > 0 {
				if best := provider.BestOriginal(trackName, artistName, results); best != nil {
					return store(best)
				}
			}
		}
	}
	return nil
}
