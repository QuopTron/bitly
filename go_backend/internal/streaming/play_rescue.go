package streaming

import (
	"fmt"
	"log"
	"strings"
	"sync"
	"time"
	"unicode"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// Circuit breaker: a provider that is rate-limited (HTTP 429) or can only give
// a non-streamable (DRM/encrypted) result gets "cooled down" for a while so the
// rescue/prefetch loop doesn't hammer it repeatedly. Without this, deezer (429)
// was retried for every quality of every queued track, saturating the executor
// and pushing getStreamPackage past the 60s RPC timeout ("Could not resolve
// URI" even though another provider had a valid stream). The breaker is shared
// with search and the download orchestrator via internal/cooldown so a provider
// that 429s anywhere is skipped fast everywhere.

// VerifyRequiredError reports that a provider HAS the exact track (resolved
// via ISRC / cross-provider id) but cannot serve its stream until the user
// completes the signed-session / Cloudflare challenge. Surfacing it as a
// structured error (instead of a generic "no stream") lets the client open
// the verification modal immediately — completing it makes the song play.
type VerifyRequiredError struct {
	// Service is the provider name whose session needs verification.
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
func isClientDecryptionError(errMsg string) bool {
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

// decryptMemo remembers providers that resolved a track but can only serve it
// via the download() pipeline (client-side decryption required — deezer
// Blowfish FLAC). The streaming chain probes the same track in several phases
// (identifiers, ISRC, name search); once any phase confirms the verdict, the
// rest skip the provider instantly instead of burning another descriptor
// resolve. Keyed by provider+resolvedID with a short TTL.
var (
	decryptMu  sync.Mutex
	decryptMem = map[string]time.Time{}
)

const decryptMemoTTL = 90 * time.Second

func decryptMemoKey(name, id string) string {
	return name + "|" + id
}

func decryptMemoHit(name, id string) bool {
	if name == "" || id == "" {
		return false
	}
	key := decryptMemoKey(name, id)
	decryptMu.Lock()
	defer decryptMu.Unlock()
	return time.Now().Before(decryptMem[key].Add(decryptMemoTTL))
}

func decryptMemoSet(name, id string) {
	if name == "" || id == "" {
		return
	}
	key := decryptMemoKey(name, id)
	decryptMu.Lock()
	defer decryptMu.Unlock()
	if len(decryptMem) > 2000 {
		now := time.Now()
		for k, v := range decryptMem {
			if now.Sub(v) > decryptMemoTTL {
				delete(decryptMem, k)
			}
		}
	}
	decryptMem[key] = time.Now()
}

// classifyStreamError classifies a GetStreamURL error for the streaming chain:
//   - client-decryption means this provider can only serve the track via the
//     download() pipeline (e.g. deezer Blowfish FLAC) — abort the whole attempt
//     NOW (probing more qualities just re-resolves the same encrypted
//     descriptor) WITHOUT cooling the provider provider-wide, which would hide
//     deezer from search and from other tracks' identifier probes while its
//     download() remains the best source.
//   - verification means the track EXISTS but the signed session must be
//     completed first — surface it fast, again without cooling (cooling made
//     the NEXT tap skip the fast path and re-enter the slow fallback walk).
//   - any other error (429/blocked/gateway) cools the provider and lets the
//     caller continue with the next quality.
//
// Returns (abort=true, err) when the provider attempt must stop; otherwise
// (abort=false, nil) to keep probing the next quality.
func classifyStreamError(name, errMsg string) (bool, error) {
	if isClientDecryptionError(errMsg) {
		return true, fmt.Errorf("stream de %s requiere descifrado cliente (solo download)", name)
	}
	if isVerificationError(errMsg) {
		cooldown.MarkOk(name)
		return true, &VerifyRequiredError{Service: name}
	}
	cooldown.MarkError(name, errMsg)
	return false, nil
}

// isVerificationError reports whether [errMsg] marks a signed-session /
// Cloudflare challenge (VERIFY_REQUIRED, "verification required", 428) rather
// than a definitive "track not available" — the track EXISTS, it just needs
// its session verified to play.
func isVerificationError(errMsg string) bool {
	if errMsg == "" {
		return false
	}
	e := strings.ToLower(errMsg)
	for _, marker := range []string{
		"verify_required",
		"verify required",
		"verification required",
		"precondition required",
		"http 428",
		"status 428",
	} {
		if strings.Contains(e, marker) {
			return true
		}
	}
	return false
}

// availableQualities returns the preferred quality plus a set of fallback
// qualities a provider is more likely to support (many providers only expose
// mp3/opus transcodes and fail on FLAC). The preferred one is tried first.
func availableQualities(preferred string) []string {
	seen := map[string]bool{}
	var out []string
	add := func(q string) {
		if q != "" && !seen[q] {
			seen[q] = true
			out = append(out, q)
		}
	}
	add(preferred)
	add("high")
	add("3")
	add("192")
	add("mp3")
	add("128")
	add("low")
	add("flac")
	return out
}

// tryStream intenta obtener stream URL de un provider especifico.
func tryStream(reg *provider.Registry, name, trackID string, track *provider.TrackResult, quality string) (string, error) {
	p := reg.Get(name)
	if p == nil {
		return "", fmt.Errorf("proveedor no encontrado: %s", name)
	}

	candidates := availableQualities(quality)

	// Verify the trackID is the RIGHT song (not a live/remix/cover) before
	// streaming it. Some extensions' getDownloadUrl resolves a name-based
	// lookup that can return a live version even when the ID looks correct.
	if track != nil && track.Title != "" && trackID != "" {
		if vID := verifyStreamMatch(p, trackID, track.Title, track.Artist, track.ISRC, true); vID == "" {
			// trackID doesn't match the queried song — skip the direct path
			// and let the ISRC path below find the correct version.
		} else {
			trackID = vID // verified or enriched
			for _, q := range candidates {
				if cooldown.IsCooled(name) {
					break
				}
				url, err := p.GetStreamURL(trackID, q)
				if err != nil {
					if abort, serr := classifyStreamError(name, err.Error()); abort {
						return "", serr
					}
					continue
				}
				if url != "" && isPlayableStreamURL(url) {
					cooldown.MarkOk(name)
					return url, nil
				}
			}
		}
	} else {
		// No title to verify against — stream directly (e.g. feed item without metadata).
		for _, q := range candidates {
			if cooldown.IsCooled(name) {
				break
			}
			url, err := p.GetStreamURL(trackID, q)
			if err != nil {
				if abort, serr := classifyStreamError(name, err.Error()); abort {
					return "", serr
				}
				continue
			}
			if url != "" && isPlayableStreamURL(url) {
				cooldown.MarkOk(name)
				return url, nil
			}
		}
	}

	// Second path: try the provider's own track ID if different from the input.
	if track != nil && track.ID != "" && track.ID != trackID {
		verifiedID := track.ID
		if track.Title != "" {
			if vID := verifyStreamMatch(p, track.ID, track.Title, track.Artist, track.ISRC, false); vID != "" {
				verifiedID = vID
			} else {
				verifiedID = "" // track.ID is a live/remix — skip
			}
		}
		if verifiedID != "" {
			for _, q := range candidates {
				if cooldown.IsCooled(name) {
					break
				}
				url, err := p.GetStreamURL(verifiedID, q)
				if err != nil {
					if abort, serr := classifyStreamError(name, err.Error()); abort {
						return "", serr
					}
					continue
				}
				if url != "" && isPlayableStreamURL(url) {
					cooldown.MarkOk(name)
					return url, nil
				}
			}
		}
	}
	if track != nil && track.ISRC != "" {
		if trackByISRC, err := p.GetTrackByISRC(track.ISRC); err == nil && trackByISRC != nil && trackByISRC.ID != "" {
			// Never stream an unverified ISRC candidate when we know the queried
			// title/artist: an extension whose ISRC search silently falls back to
			// a name search (SoundCloud re-uploads, wrong mappings) would serve a
			// different song. verifyStreamMatch re-fetches the resolved id and
			// rejects it on ISRC mismatch / weak title+artist strength.
			if track.Title != "" {
				if verified := verifyStreamMatch(p, trackByISRC.ID, track.Title, track.Artist, track.ISRC, true); verified == "" {
					return "", fmt.Errorf("stream de %s no es la cancion solicitada", name)
				}
			}
			for _, q := range candidates {
				if cooldown.IsCooled(name) {
					break
				}
				if url, err := p.GetStreamURL(trackByISRC.ID, q); err != nil {
					if abort, serr := classifyStreamError(name, err.Error()); abort {
						return "", serr
					}
				} else if url != "" && isPlayableStreamURL(url) {
					cooldown.MarkOk(name)
					return url, nil
				}
			}
		}
	}
	return "", fmt.Errorf("stream no disponible en %s", name)
}

// streamingProviderOrder returns the streaming providers that are actually
// registered, best-first — the same effective order the download orchestrator
// uses (exact sources first: deezer/qobuz/tidal/amazon, then youtube/ytmusic,
// with soundcloud's loose name-search last). Unlike [streamingProviders] it
// reflects the live registry (extension-loaded names), so a registered
// source is never skipped and a missing one is never probed.
func streamingProviderOrder(reg *provider.Registry) []string {
	if reg == nil {
		return nil
	}
	var out []string
	seen := map[string]bool{}
	neverStream := map[string]bool{
		"musicbrainz": true,
		"spotify":     true,
		"apple":       true,
	}
	for _, name := range streamingProviders {
		p := reg.Get(name)
		if p == nil || neverStream[name] {
			continue
		}
		if ep, ok := p.(*provider.ExtensionProvider); ok && !ep.DownloadCapable() {
			continue
		}
		out = append(out, name)
		seen[name] = true
	}
	for _, name := range reg.Names() {
		if seen[name] || neverStream[name] || !isStreamingProvider(name) {
			continue
		}
		p := reg.Get(name)
		if ep, ok := p.(*provider.ExtensionProvider); ok && !ep.DownloadCapable() {
			continue
		}
		out = append(out, name)
	}
	return out
}

// rescueProviderOnce probes ONE provider for a playable stream, honoring the
// preferred-quality list and the circuit breaker, and returns a playable URL or
// "". The second return reports whether the provider resolved the EXACT track
// but needs its signed session verified before it can stream (VERIFY_REQUIRED)
// — the caller surfaces that as a fast fail instead of re-walking the whole
// fallback chain. This is the unit of work raced in parallel below (it is
// fully self-contained so goroutines never share mutable state).
func rescueProviderOnce(p provider.Provider, resolvedID string, quality string) (string, bool) {
	if resolvedID == "" {
		return "", false
	}
	// A previous phase already learned this provider needs client-side
	// decryption for this track (deezer Blowfish FLAC): skip it instantly
	// instead of re-resolving the encrypted descriptor.
	if decryptMemoHit(p.Name(), resolvedID) {
		return "", false
	}
	for _, q := range availableQualities(quality) {
		if cooldown.IsCooled(p.Name()) {
			break
		}
		if url, err := p.GetStreamURL(resolvedID, q); err != nil {
			// A verified session is the ONLY thing standing between the user and
			// the song — surface it immediately instead of probing more
			// qualities that will fail the same way. Deliberately do NOT cool
			// the provider: cooling a verify-pending source makes the NEXT tap
			// skip it in the fast race and fall back into the slow multi-provider
			// walk (10-30s), which then re-discovers the same verification need.
			// Clearing any stale cooldown keeps it probeable so EVERY tap
			// fail-fasts in ~2-4s until the user completes the challenge.
			if isVerificationError(err.Error()) {
				cooldown.MarkOk(p.Name())
				return "", true
			}
			// Client-decryption: the track exists here but direct streaming is
			// impossible — only download() (which performs the decryption) can
			// serve it. Skip this provider fast (no more quality probes) and
			// remember the verdict so later phases don't re-probe it. Do NOT
			// cool it provider-wide: deezer stays the best DOWNLOAD source and
			// must remain probeable by the download pipeline's identifier walk.
			if isClientDecryptionError(err.Error()) {
				decryptMemoSet(p.Name(), resolvedID)
				return "", false
			}
			cooldown.MarkError(p.Name(), err.Error())
		} else if url != "" && isPlayableStreamURL(url) {
			cooldown.MarkOk(p.Name())
			return url, false
		}
	}
	return "", false
}

// rescueRace runs [attempt] for every provider in [names] concurrently (bounded
// by [workers]) and returns the first success, honoring [names] order when
// several finish together. [budget] bounds how long the phase may take — the
// whole point over the old serial walk is that a slow/hanging provider (captcha,
// cold session) stops eating the total time for every later provider. Attempts
// still running when the phase ends are abandoned (their HTTP calls eventually
// time out on their own); they never gate the result.
// rescueOut is a single race worker result: the provider name and the stream
// URL it resolved (empty when it found nothing).
type rescueOut struct {
	name string
	url  string
}

// rescueRace runs [attempt] for every provider concurrently (bounded by
// [workers]) and returns the first stream success, honoring [names] order when
// several finish together. The attempt returns (url, verified): verified=true
// means the provider resolved the EXACT track but needs its signed session
// before streaming — the race then returns ("", provider, true) IMMEDIATELY
// (the fastest provider to hit the challenge wins) so the caller can surface
// the verification modal in ~1-2s instead of walking every provider.
func rescueRace(reg *provider.Registry, names []string, budget time.Duration, workers int, attempt func(name string, p provider.Provider) (string, bool)) (string, string, bool) {
	if len(names) == 0 {
		return "", "", false
	}
	results := make(chan rescueOut, len(names))
	verifyCh := make(chan string, len(names))
	done := make(chan struct{})
	var wg sync.WaitGroup
	sem := make(chan struct{}, workers)
	deadline := time.Now().Add(budget)

	// Spawn workers, but NEVER let the semaphore block the caller: a worker
	// leaked from a previous race (a JS call that never returns holds its
	// sandbox mutex + its sem slot) would otherwise deadlock this spawn loop
	// BEFORE any budget exists — the whole request hangs forever. Each
	// provider gets a short window to claim a slot (a fast provider frees its
	// slot in ~1s); if none frees, skip that provider and try the next, so a
	// permanently-stuck slot costs seconds, not the whole budget.
	for _, name := range names {
		name := name
		p := reg.Get(name)
		if p == nil {
			continue
		}
		if cooldown.IsCooled(name) {
			continue
		}
		wait := time.Second
		if rem := time.Until(deadline); rem < wait {
			wait = rem
		}
		select {
		case sem <- struct{}{}:
			wg.Add(1)
			go func() {
				defer wg.Done()
				defer func() { <-sem }()
				url, verified := attempt(name, p)
				if verified {
					verifyCh <- name
					return
				}
				if url != "" {
					results <- rescueOut{name, url}
				}
			}()
		case <-time.After(wait):
			// No slot freed in time — skip this provider; anything already
			// running may still report via drainResults.
		}
	}
	go func() { wg.Wait(); close(done) }()

	return drainResults(results, verifyCh, done, &deadline)
}

// verifyGrace is how long a verification signal waits for a real stream to
// land before committing to the "needs session" verdict. A provider that only
// needs verification usually fails in ~1s, while a working provider may take a
// few seconds to resolve — without the grace, the fast verify signal would
// preempt a slower but genuinely playable source.
const verifyGrace = 1500 * time.Millisecond

// drainResults collects race results until either every worker finished, a
// verification signal arrived (honored after a short grace), or the shared
// deadline passes, honoring provider order when several finish together. A
// fresh timer per call is used (never a consumed one) so returning from the
// spawn loop on deadline can't wedge on an already-fired channel.
func drainResults(results <-chan rescueOut, verifyCh <-chan string, done <-chan struct{}, deadline *time.Time) (string, string, bool) {
	best := ""
	bestName := ""
	var verifyName string
	var graceCh <-chan time.Time
	var graceTimer *time.Timer
	for {
		select {
		case r := <-results:
			if r.url == "" {
				continue
			}
			// First success wins — and return immediately instead of waiting
			// out the budget: a leaked worker that never closes [done] must
			// not delay an already-resolved stream (that delay is what made
			// the second tap in a queue feel stuck at 00:00).
			if graceTimer != nil {
				graceTimer.Stop()
			}
			return r.url, r.name, false
		case v := <-verifyCh:
			if verifyName == "" {
				verifyName = v
			}
			if graceTimer == nil {
				graceTimer = time.NewTimer(verifyGrace)
				graceCh = graceTimer.C
			}
			// Keep waiting through the grace for a real stream.
		case <-graceCh:
			// A provider has the exact track but needs its session verified:
			// no stream landed during the grace — return the verdict so the
			// client opens the modal instead of the caller burning 10-30s on
			// a doomed fallback walk.
			return "", verifyName, true
		case <-done:
			if graceTimer != nil {
				graceTimer.Stop()
			}
			if verifyName != "" && best == "" {
				return "", verifyName, true
			}
			return best, bestName, false
		case <-time.After(time.Until(*deadline)):
			if graceTimer != nil {
				graceTimer.Stop()
			}
			if verifyName != "" && best == "" {
				return "", verifyName, true
			}
			return best, bestName, false
		}
	}
}

// rescueStream busca un stream URL en TODOS los providers que streamean.
// Los intentos por ISRC y por nombre corren en PARALELO entre providers con
// ventanas acotadas, de modo que un provider lento (captcha/sesión fría/429)
// ya no suma su tiempo a cada provider posterior — el más rápido gana en
// segundos en vez de arrastrar 60-100s como el walk serial anterior.
// [verified] reports that a provider HAS the exact track but needs its signed
// session to stream it — the caller fails fast on that verdict.
func rescueStream(reg *provider.Registry, track *provider.TrackResult, trackName, artistName, quality string) (url, prov string, attempted []string, verified bool) {
	names := streamingProviderOrder(reg)

	// Phase 1: every provider resolves the same track via ISRC (exact match) in
	// parallel. Fast ~1-2s when the exact source is up; bounded so a provider
	// with a cold session never blocks the others. A provider that HAS the
	// track but needs its session verified is reported as a verify signal so
	// the caller fails fast instead of walking the whole chain.
	if track != nil && track.ISRC != "" {
		u, provName, v := rescueRace(reg, names, 8*time.Second, 2, func(name string, p provider.Provider) (string, bool) {
			trackByISRC, err := p.GetTrackByISRC(track.ISRC)
			if err != nil || trackByISRC == nil || trackByISRC.ID == "" {
				return "", false
			}
			// Even an ISRC-resolved candidate is verified against the queried
			// title/artist when we have them: an extension whose ISRC search
			// silently falls back to a name search (e.g. SoundCloud re-uploads
			// or a wrong mapping) must never serve an unrelated song.
			if trackName != "" && verifyStreamMatch(p, trackByISRC.ID, trackName, artistName, track.ISRC, true) == "" {
				return "", false
			}
			return rescueProviderOnce(p, trackByISRC.ID, quality)
		})
		if v {
			return "", provName, nil, true
		}
		if u != "" {
			return u, provName, nil, false
		}
		attempted = append(attempted, names...)
	}

	// Phase 2: strict original-track name search across providers, also in
	// parallel (the same rankedMatches filter used before, so a wrong/similar
	// upload is never served). A strict match whose stream needs verification
	// is surfaced the same way.
	if trackName != "" && artistName != "" {
		u, provName, v := rescueRace(reg, names, 10*time.Second, 2, func(name string, p provider.Provider) (string, bool) {
			results, err := p.SearchTracks(trackName+" "+artistName, 8)
			if err != nil || len(results) == 0 {
				return "", false
			}
			var sawVerify bool
			for _, cand := range rankedMatches(trackName, artistName, results) {
				candURL, cv := rescueProviderOnce(p, cand.ID, quality)
				if cv {
					sawVerify = true
					continue
				}
				if candURL != "" {
					return candURL, false
				}
			}
			if sawVerify {
				return "", true
			}
			return "", false
		})
		if v {
			return "", provName, nil, true
		}
		if u != "" {
			return u, provName, nil, false
		}
		attempted = append(attempted, names...)
	}
	return "", "", attempted, false
}

// RescueStreamURL probes every registered FULL-STREAM provider (deezer,
// soundcloud, ytmusic, youtube) for a direct http stream of the exact track,
// resolved via its identifiers (ISRC / cross-provider ids, then a strict
// original-track name search) — the same fast route StreamQuick uses for the
// preferred provider, but across all full-stream providers. It is the "instant
// stream" pass used before the slow download pipeline for tracks whose
// preferred source (tidal/apple/amazon/qobuz/spotify-web) exposes no direct
// stream. Returns (url, provider, err).
// rescueByIdentifiers probes every FULL-STREAM provider for the EXACT track via
// its cross-provider identifiers — the same CheckAvailability route StreamQuick
// uses for the preferred provider, raced in parallel across all full-stream
// providers. This is the fastest path for a tidal/amazon/qobuz/spotify track
// that carries a cross-provider id: each provider resolves the id (or ISRC) in
// ~1-2s with no name search at all.
func rescueByIdentifiers(reg *provider.Registry, quality, isrc, spotifyID, deezerID, tidalID, qobuzID, trackName, artistName string) (string, string, bool) {
	if isrc == "" && spotifyID == "" && deezerID == "" && tidalID == "" && qobuzID == "" {
		return "", "", false
	}
	names := streamingProviderOrder(reg)
	url, prov, verified := rescueRace(reg, names, 5*time.Second, 2, func(name string, p provider.Provider) (string, bool) {
		resolvedID := ""
		if ep, ok := p.(*provider.ExtensionProvider); ok {
			if id, found := ep.CheckAvailability(isrc, trackName, artistName, spotifyID, deezerID, tidalID, qobuzID, 0); found && id != "" {
				resolvedID = id
			}
		}
		if resolvedID == "" && isrc != "" {
			if t, err := p.GetTrackByISRC(isrc); err == nil && t != nil && t.ID != "" {
				resolvedID = t.ID
			}
		}
		if resolvedID == "" {
			return "", false
		}
		// Same guard as rescueStream phase 1: never stream an unverified
		// candidate when we know the requested title/artist.
		if trackName != "" && verifyStreamMatch(p, resolvedID, trackName, artistName, isrc, true) == "" {
			return "", false
		}
		return rescueProviderOnce(p, resolvedID, quality)
	})
	return url, prov, verified
}

func RescueStreamURL(reg *provider.Registry, quality, isrc, spotifyID, deezerID, tidalID, qobuzID, trackName, artistName string) (string, string, error) {
	if reg == nil {
		return "", "", fmt.Errorf("no inicializado")
	}
	// If we have no identifier and no name, there is nothing to resolve with.
	if isrc == "" && spotifyID == "" && deezerID == "" && tidalID == "" && qobuzID == "" && trackName == "" {
		return "", "", fmt.Errorf("sin identificador de track")
	}
	// Phase 0 — identifiers first: the exact track resolved via cross-provider
	// ids / ISRC, raced in parallel across every full-stream provider. A track
	// from ANY source (search item, album/playlist/artist detail, feed) that
	// carries spotify/deezer/tidal/qobuz id or an ISRC starts playing in ~1-2s
	// instead of falling into the slow name-search below. Search results in
	// particular often lack an ISRC but always carry the source provider's id.
	if url, prov, verified := rescueByIdentifiers(reg, quality, isrc, spotifyID, deezerID, tidalID, qobuzID, trackName, artistName); url != "" {
		return url, prov, nil
	} else if verified {
		// The exact track EXISTS on a full-stream provider that only needs its
		// session verified — fail fast so the client opens the modal instead
		// of walking every provider for 10-30s to reach the same verdict.
		return "", prov, &VerifyRequiredError{Service: prov}
	}
	track := &provider.TrackResult{
		ISRC:   isrc,
		Title:  trackName,
		Artist: artistName,
	}
	url, prov, attempted, verified := rescueStream(reg, track, trackName, artistName, quality)
	if url != "" {
		return url, prov, nil
	}
	if verified {
		return "", prov, &VerifyRequiredError{Service: prov}
	}
	if len(attempted) > 0 {
		return "", "", fmt.Errorf("sin stream en: %s", strings.Join(attempted, ", "))
	}
	return "", "", fmt.Errorf("sin stream en ningun proveedor")
}

// asciiFold transliterates common accented chars so matching works across
// providers that may or may not keep accents (e.g. "café" vs "cafe").
func asciiFold(s string) string {
	r := strings.NewReplacer(
		"á", "a", "à", "a", "ä", "a", "â", "a", "ã", "a",
		"é", "e", "è", "e", "ë", "e", "ê", "e",
		"í", "i", "ì", "i", "ï", "i", "î", "i",
		"ó", "o", "ò", "o", "ö", "o", "ô", "o", "õ", "o",
		"ú", "u", "ù", "u", "ü", "u", "û", "u",
		"ñ", "n", "ç", "c",
	)
	return r.Replace(s)
}

// noiseWords are tokens that don't identify a song and can appear in only one
// side of a match (official video/lyrics/remaster etc.). Stripping them makes
// title/artist comparison fairer.
var noiseWords = map[string]bool{
	"official": true, "video": true, "audio": true, "lyrics": true, "lyric": true,
	"hd": true, "4k": true, "remaster": true, "remastered": true, "version": true,
	"feat": true, "featuring": true, "ft": true, "with": true, "live": true,
	"album": true, "single": true, "ep": true, "edit": true, "radio": true,
}

// norm lowercases, folds accents, removes punctuation and noise words, and
// collapses whitespace so strings compare on the meaningful words only.
func norm(s string) string {
	s = asciiFold(strings.ToLower(s))
	var b strings.Builder
	prevSpace := true
	for _, r := range s {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			b.WriteRune(r)
			prevSpace = false
		} else if !prevSpace {
			b.WriteByte(' ')
			prevSpace = true
		}
	}
	fields := strings.Fields(b.String())
	out := make([]string, 0, len(fields))
	for _, w := range fields {
		if !noiseWords[w] {
			out = append(out, w)
		}
	}
	return strings.Join(out, " ")
}

// tokenOverlap returns the fraction of tokens shared between two strings.
func tokenOverlap(a, b string) float64 {
	ta := strings.Fields(a)
	tb := strings.Fields(b)
	if len(ta) == 0 || len(tb) == 0 {
		return 0
	}
	set := map[string]bool{}
	for _, w := range ta {
		set[w] = true
	}
	hits := 0
	for _, w := range tb {
		if set[w] {
			hits++
		}
	}
	denom := len(ta)
	if len(tb) > denom {
		denom = len(tb)
	}
	return float64(hits) / float64(denom)
}

// titleScore / artistScore: >=2 means equality or containment (strong), 1 is
// weak token overlap, 0 is no match.
func fieldScore(q, r string) float64 {
	if q == "" || r == "" {
		return 0
	}
	if q == r {
		return 3
	}
	if strings.Contains(r, q) || strings.Contains(q, r) {
		return 2
	}
	if tokenOverlap(q, r) >= 0.6 {
		return 1
	}
	return 0
}

// bestMatch picks the search result that best corresponds to the queried
// track/artist, returning the match and its per-field scores so the caller can
// require a strong match before serving a stream (avoid wrong versions/covers).
func bestMatch(queryTitle, queryArtist string, results []provider.TrackResult) (*provider.TrackResult, float64, float64) {
	qt := norm(queryTitle)
	qa := norm(queryArtist)
	var best *provider.TrackResult
	var bestTitle, bestArtist float64
	for i := range results {
		t := fieldScore(qt, norm(results[i].Title))
		a := fieldScore(qa, norm(results[i].Artist))
		if t+a > bestTitle+bestArtist {
			best = &results[i]
			bestTitle = t
			bestArtist = a
		}
	}
	return best, bestTitle, bestArtist
}

// rankedMatches returns the search results sorted best-first by combined
// title+artist score, keeping only candidates that are the ORIGINAL track
// (strong artist AND strong title AND non-variant title via
// provider.OriginalStrength). When no strict original exists it falls back to
// a best-effort pass (strong title + non-variant relative to the query) so the
// rescue can still serve a re-upload of the same song instead of playing
// nothing — different songs (weak title, or covers/remixes the query lacks)
// are still excluded.
func rankedMatches(queryTitle, queryArtist string, results []provider.TrackResult) []provider.TrackResult {
	ranked := provider.RankOriginalCandidates(queryTitle, queryArtist, results)
	if len(results) > 0 && len(ranked) == 0 {
		log.Printf("[rescue] %q / %q: %d results, sin candidato reproducible. Candidatos:",
			queryTitle, queryArtist, len(results))
		for i := range results {
			tt := provider.FieldScore(queryTitle, results[i].Title)
			aa := provider.FieldScore(queryArtist, results[i].Artist)
			log.Printf("  [%d] t=%.0f a=%.0f | %q | %q | nonorig=%v", i, tt, aa,
				results[i].Title, results[i].Artist, provider.IsNonOriginalTitle(results[i].Title))
		}
	}
	return ranked
}
