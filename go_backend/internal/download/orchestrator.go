package download

import (
	"bytes"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
	"github.com/zarz/bitly/go_backend/internal/provider/youtube"
)

// Request represents a download request from Flutter.
// The strategy payload uses snake_case keys; DownloadByStrategy maps them.
type Request struct {
	ItemID    string `json:"itemId"`
	Title     string `json:"title"`
	Artist    string `json:"artist"`
	Album     string `json:"album"`
	ISRC      string `json:"isrc"`
	Provider  string `json:"provider"`
	TrackID   string `json:"trackId"`
	Quality   string `json:"quality"`
	OutputDir string `json:"outputDir"`
	Type      string `json:"type"`
	LyricsSrc string `json:"source"`
	// Cross-provider ids (optional) used for richer fallback matching, mirroring
	// the reference middleware's CheckAvailabilityForItemID inputs.
	SpotifyID  string `json:"spotifyId,omitempty"`
	DeezerID   string `json:"deezerId,omitempty"`
	TidalID    string `json:"tidalId,omitempty"`
	QobuzID    string `json:"qobuzId,omitempty"`
	DurationMS int    `json:"durationMs,omitempty"`
}

// Result holds the outcome of a download.
type Result struct {
	ItemID    string `json:"itemId"`
	Success   bool   `json:"success"`
	Provider  string `json:"provider,omitempty"`
	StreamURL string `json:"streamUrl,omitempty"`
	FilePath  string `json:"filePath,omitempty"`
	Encrypted bool   `json:"encrypted,omitempty"`
	Error     string `json:"error,omitempty"`
	// ClientDecrypt is set when the provider handed back an encrypted/DRM file
	// with a decryption key but no CLI ffmpeg is available on this platform
	// (e.g. Android). The file is kept on disk so the client can decrypt it
	// (e.g. via ffmpeg-kit) and then play it.
	ClientDecrypt   bool   `json:"clientDecrypt,omitempty"`
	DecryptionKey   string `json:"decryptionKey,omitempty"`
	OutputExtension string `json:"outputExtension,omitempty"`
	// ErrorType classifies failures (e.g. "verification_required") so the
	// client can react (open a Cloudflare challenge) instead of failing blindly.
	ErrorType string `json:"errorType,omitempty"`
	// Service names the provider involved in an error (e.g. which one needs
	// verification), mirroring the reference middleware's "Service" field.
	Service string `json:"service,omitempty"`
}

// Orchestrator manages downloads with provider fallback.
// A provider may either expose a full JS download() (extensions) or a
// stream URL (native providers). In both cases the audio is written to
// disk so Flutter can play the local file and persist it in Drift.
type Orchestrator struct {
	providers     *provider.Registry
	tracker       *Tracker
	mu            sync.Mutex
	active        map[string]bool
	fallbackOrder []string
	concurrency   chan struct{}
}

// maxConcurrentDownloads caps how many downloads run at once to avoid
// overwhelming low-end devices. Overridable via SetConcurrency.
const maxConcurrentDownloads = 3

// maxParallelCandidates bounds how many resolved providers are raced in
// parallel for a single download. The warm resolve already surfaced the fastest
// sources first, so beyond this a slow extra candidate just wastes budget.
const maxParallelCandidates = 4

// maxParallelDownloads caps simultaneous in-flight download attempts for ONE
// request (the "second plans" race). Providers that fail fast (429/verification)
// release their slot quickly, so this rarely saturates.
const maxParallelDownloads = 3

// authorityGrace is how long the download race waits, after a last-resort
// (name-search) provider finishes first, for an exact/authoritative companion
// (still in flight) to land the real original before accepting the faster but
// possibly-wrong source. Kept short so a stream is never held up noticeably.
const authorityGrace = 3 * time.Second

// lastResortProviders are the lossy, name-search sources whose "same title"
// results can occasionally be a remix/cover/wrong upload. In the parallel race
// they never win over an exact source that is still downloading; they only win
// when no exact source can finish.
var lastResortProviders = []string{"soundcloud", "youtube"}

func isLastResortProvider(name string) bool {
	for _, p := range lastResortProviders {
		if p == name {
			return true
		}
	}
	return false
}

// downloadCooldownOp scopes this package's circuit-breaker state to the
// "download" operation bucket. Downloads hitting 429/rate-limits cool the
// provider ONLY for downloads (and stream fallback), never for search/feed —
// so a big download that rate-limits a few providers can't leave the next
// search looking "empty".
const downloadCooldownOp = "download"

// maxFallbackDuration bounds how long the multi-provider fallback may keep
// starting new attempts. The Android RPC channel times out getStreamPackage
// after 60s, so staying well under it lets the orchestrator return a
// structured error (errorType/service) instead of being killed mid-flight.
const maxFallbackDuration = 50 * time.Second

// raceResolutionTimeout is how long the preferred (owner) provider is allowed
// to resolve before the playback race hands off to whichever provider was ready
// first. Short enough to keep first-play fast on slow sources (e.g. amazon's
// web search), long enough that the preferred high-quality source usually wins.
const raceResolutionTimeout = 5 * time.Second

// NewOrchestrator creates a download orchestrator with fallback chain.
func NewOrchestrator(reg *provider.Registry) *Orchestrator {
	return &Orchestrator{
		providers:     reg,
		tracker:       NewTracker(),
		active:        make(map[string]bool),
		concurrency:   make(chan struct{}, maxConcurrentDownloads),
		fallbackOrder: buildFallbackOrder(reg),
	}
}

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
// registered, preferring [preferredStreamOrder] and appending any remaining
// streaming-capable providers. Metadata-only providers (musicbrainz, and
// extensions without a download capability) are excluded.
func buildFallbackOrder(reg *provider.Registry) []string {
	var order []string
	seen := map[string]bool{}
	// Native-only non-streamers that may still be registered.
	neverStream := map[string]bool{
		"musicbrainz": true,
		"spotify":     true,
		"apple":       true,
	}
	for _, name := range preferredStreamOrder {
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

// SetConcurrency replaces the concurrency limiter. Must be called while no
// downloads are active (e.g. from config sync before batches start).
func (o *Orchestrator) SetConcurrency(n int) {
	if n < 1 {
		n = 1
	}
	o.mu.Lock()
	o.concurrency = make(chan struct{}, n)
	o.mu.Unlock()
}

// Download executes a single download with provider fallback.
// It acquires a concurrency slot so bursts of batch downloads don't
// saturate the device's CPU, network or disk.
func (o *Orchestrator) Download(req Request) *Result {
	o.mu.Lock()
	if o.active[req.ItemID] {
		o.mu.Unlock()
		return &Result{ItemID: req.ItemID, Success: false, Error: "already downloading"}
	}
	o.active[req.ItemID] = true
	o.mu.Unlock()

	defer func() {
		o.mu.Lock()
		delete(o.active, req.ItemID)
		o.mu.Unlock()
	}()

	o.tracker.Add(req.ItemID, req.Title, req.Provider)

	// Acquire a concurrency slot (blocking, but bounded).
	o.concurrency <- struct{}{}
	defer func() { <-o.concurrency }()

	providersToTry := o.fallbackOrder
	if req.Provider != "" {
		providersToTry = append([]string{req.Provider}, o.fallbackOrder...)
	}

	outDir := req.OutputDir
	if outDir == "" {
		outDir = GlobalOutputDir()
	}

	// Enrich the request's ISRC when the feed item didn't carry one (e.g.
	// tidal/apple/qobuz feeds, or tracks with isrc=null). We try the source
	// provider's own track first, then each cross-provider id via spotify (its
	// metadata carries ISRC reliably), so a track reached from ANY feed gets a
	// strict ISRC. Providers like amazon resolve via SongLink using the ISRC, so
	// the same exact source can be served instead of falling back to a lossy
	// same-title remix on soundcloud/ytmusic.
	if req.ISRC == "" {
		enrich := func(pn string, id string) {
			if req.ISRC != "" || id == "" || pn == "" {
				return
			}
			if sp := o.providers.Get(pn); sp != nil {
				if t, err := sp.GetTrack(stripTrackPrefix(id)); err == nil && t != nil && t.ISRC != "" {
					req.ISRC = t.ISRC
				}
			}
		}
		// Each provider's own track lookup is the most reliable ISRC source for
		// its own id (deezer/qobuz/tidal/spotify all expose isrc in GetTrack).
		enrich(req.Provider, req.TrackID)
		enrich("deezer", req.DeezerID)
		enrich("tidal", req.TidalID)
		enrich("qobuz", req.QobuzID)
		enrich("spotify-web", req.SpotifyID)
		enrich(req.Provider, req.SpotifyID)
		enrich("spotify-web", req.TrackID)
	}

	var lastErr string
	var encryptedSeen bool
	var verificationService string
	fallbackStart := time.Now()

	// Resolve the track's identity ONCE and share it across every provider: the
	// key is the same (ISRC / identifiers / title+artist) for all of them, so a
	// slow name search (amazon showSearch, etc.) done for one provider never has
	// to be repeated for the others.
	lookKey := req.ISRC
	if lookKey == "" {
		lookKey = strings.Join([]string{req.SpotifyID, req.DeezerID, req.TidalID, req.QobuzID}, "|")
	}
	if lookKey == "" && req.Title != "" {
		lookKey = strings.ToLower(req.Title + "|" + req.Artist)
	}

	// Resolve every candidate provider's track ID in parallel so the fallback
	// loop below never stalls serially on a single provider's slow web search
	// (amazon showSearch etc.). While the preferred provider is still resolving
	// we hand off to whichever provider finished first, so the first play of a
	// brand-new track starts immediately on slow sources.
	type warmRes struct {
		name                   string
		trackID, title, artist string
		took                   time.Duration
	}
	resCh := make(chan warmRes, len(providersToTry)+1)
	warm := func(name string, pr provider.Provider) {
		start := time.Now()
		id, t, a := cachedResolve(pr, name, lookKey, req)
		resCh <- warmRes{name, id, t, a, time.Since(start)}
	}
	{
		var wg sync.WaitGroup
		sem := make(chan struct{}, 3)
		for _, name := range providersToTry {
			if name == req.Provider && req.Provider == "" {
				continue
			}
			p := o.providers.Get(name)
			if p == nil {
				continue
			}
			if ep, ok := p.(*provider.ExtensionProvider); ok && !ep.DownloadCapable() {
				continue
			}
			if cooldown.IsCooledOp(name, downloadCooldownOp) {
				continue
			}
			wg.Add(1)
			sem <- struct{}{}
			go func(n string, pr provider.Provider) {
				defer wg.Done()
				defer func() { <-sem }()
				warm(n, pr)
			}(name, p)
		}
		go func() {
			wg.Wait()
			close(resCh)
		}()
	}

	// Wait up to the race window for the preferred provider to resolve, while
	// collecting the arrival order of every provider. If the preferred one is
	// slow we already know which fallbacks are ready and can jump straight to
	// them. Anything still resolving keeps running in the background and its
	// result is picked up on a later attempt (it is cached by cachedResolve).
	arrival := []warmRes{}
	resolved := map[string]warmRes{}
	raceDone := false
	deadline := time.Now().Add(raceResolutionTimeout)
	for !raceDone {
		left := time.Until(deadline)
		if left <= 0 {
			raceDone = true
			break
		}
		select {
		case r, ok := <-resCh:
			if !ok {
				raceDone = true
				continue
			}
			arrival = append(arrival, r)
			if r.trackID != "" {
				resolved[r.name] = r
			}
			if r.name == req.Provider && r.trackID != "" {
				raceDone = true
			}
		case <-time.After(left):
			raceDone = true
		}
	}

	// Reorder the try-list: the preferred (owner) provider first when it
	// resolved, then the other resolved providers in arrival order (fastest
	// first), then any still-unresolved candidates in their original order.
	tryOrder := make([]string, 0, len(providersToTry))
	seen := map[string]bool{}
	addTry := func(name string) {
		if name == "" || seen[name] {
			return
		}
		seen[name] = true
		tryOrder = append(tryOrder, name)
	}
	if req.Provider != "" {
		if _, ok := resolved[req.Provider]; ok {
			addTry(req.Provider)
		}
	}
	for _, r := range arrival {
		if r.trackID == "" {
			continue
		}
		if req.Provider != "" && r.name == req.Provider {
			continue
		}
		addTry(r.name)
	}
	for _, name := range providersToTry {
		addTry(name)
	}

	// Build the candidate list: every provider that resolved a track id for
	// this item. This phase only resolves + reverse-verifies (no network
	// download) and is bounded so we never spend the whole budget enumerating.
	type providerAttempt struct {
		name                   string
		p                      provider.Provider
		trackID, title, artist string
	}
	candidates := make([]providerAttempt, 0, maxParallelCandidates)
	for _, name := range tryOrder {
		// The Android RPC channel enforces a 60s timeout on getStreamPackage;
		// once this budget is spent we stop starting NEW provider attempts (a
		// provider already mid-download is never interrupted) and return a
		// structured error inside the window instead of being killed by the
		// client-side timeout mid-flight.
		if time.Since(fallbackStart) > maxFallbackDuration {
			lastErr = "fallback: tiempo de búsqueda agotado"
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
		trackID, title, artist := cachedResolve(p, name, lookKey, req)
		if trackID == "" {
			continue
		}
		// A provider other than the owner resolved the track (cross-provider id,
		// ISRC or search): never download a wrong/similar song. Reverse-verify the
		// resolved id against the requested title/artist via the provider's own
		// record; the owner's own native id is trusted (it IS the source track).
		if name != req.Provider && req.Title != "" {
			if !confirmDownloadMatch(p, trackID, req.ISRC, req.Title, req.Artist, req.DurationMS) {
				lastErr = fmt.Sprintf("%s: el stream no es la cancion solicitada", name)
				continue
			}
		}
		candidates = append(candidates, providerAttempt{name, p, trackID, title, artist})
		if len(candidates) >= maxParallelCandidates {
			break
		}
	}

	// Fire every candidate's download in parallel ("second plans" delegated to
	// goroutines). The first source to yield a playable, verified file wins;
	// the remaining companions keep running but their results are discarded and
	// their partial ".tmp." files are never served (StreamCacheFile skips them).
	// This converts the previously serial 50s budget into a race where the
	// fastest working source starts producing the file immediately.
	if len(candidates) > 0 {
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

		// A last-resort provider (soundcloud/youtube name-search) is small and
		// finishes first, but it can be a wrong/similar upload of the song. So
		// the FIRST finishing provider does not automatically win: an exact
		// (lossless/identifier-resolving) source lands immediately, while a
		// last-resort source must wait a short grace window for an exact
		// companion (still in flight) to land the real original. Only when no
		// exact candidate remains in flight, or the grace elapses, is the
		// last-resort source accepted — so the common "original wins" case stays
		// fast while remixes are rejected as the default.
		exactInFlight := 0
		for _, c := range candidates {
			if !isLastResortProvider(c.name) {
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
					if !isLastResortProvider(res.Provider) {
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
					lastErr = res.Error
				}
				if res.Service != "" {
					verificationService = res.Service
				}
				if strings.Contains(res.Error, "encriptado") {
					encryptedSeen = true
				}
				if !isLastResortProvider(res.Provider) {
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
	}

	o.tracker.SetError(req.ItemID, "all providers failed")
	if encryptedSeen {
		lastErr = "solo stream encriptado no reproducible en todos los providers"
	}
	return &Result{
		ItemID:    req.ItemID,
		Success:   false,
		Provider:  verificationService,
		Error:     lastErr,
		ErrorType: classifyVerificationError(lastErr),
		Service:   verificationService,
	}
}

// attemptDownload runs ONE provider's full download pipeline for [req]. It is
// invoked concurrently for every resolved candidate so the fastest working
// source wins. It returns a Result: Success=true with the produced file/stream
// on success, or Success=false carrying the failure message, the verification
// service (if any) and an "encriptado" marker so the caller can aggregate.
func (o *Orchestrator) attemptDownload(req Request, name string, p provider.Provider, trackID, title, artist, outDir string) *Result {
	o.tracker.Update(req.ItemID, StatusDownloading, 0.1)
	o.tracker.SetTrackInfo(req.ItemID, title, artist)

	// Full extension download pipeline (writes file to disk, reports real progress).
	if ep, ok := p.(*provider.ExtensionProvider); ok && outDir != "" {
		o.tracker.Update(req.ItemID, StatusDownloading, 0.2)
		// The extension download() expects a full destination path, not a
		// directory. Build a basename from the track id (or title); a unique
		// ".tmp.<provider>" suffix keeps concurrent companion downloads for the
		// same item from colliding on one filename.
		extBase := req.ItemID
		if extBase == "" {
			extBase = title + " - " + artist
		}
		extDest := filepath.Join(outDir, sanitizeFilename(extBase)+".tmp."+sanitizeFilename(name))
		result := ep.Download(trackID, qualityForProvider(p, req.Quality), extDest, func(percent int) {
			o.tracker.Update(req.ItemID, StatusDownloading, 0.2+float64(percent)/100.0*0.7)
		})
		if !result.Success {
			cooldown.MarkOpError(name, downloadCooldownOp, result.Error)
			if vt := classifyVerificationError(result.Error); vt != "" {
				// Remember the verification-needing provider so we can surface it
				// only if every provider ends up streamless.
				o.tracker.SetError(req.ItemID, "verification required")
				return &Result{ItemID: req.ItemID, Success: false, Error: "Download failed: " + result.Error, ErrorType: vt, Service: name}
			}
			return &Result{ItemID: req.ItemID, Success: false, Error: result.Error}
		}
		if result.FilePath == "" {
			return &Result{ItemID: req.ItemID, Success: false, Error: fmt.Sprintf("%s: sin archivo", name)}
		}
		// Double-check the downloaded file is the ORIGINAL song. The extension
		// reports the real title/artist of what it put on disk; if they don't
		// strongly match the request, discard it so another provider serves the
		// original instead of a wrong version (cover/remix/wrong artist).
		if req.Title != "" && (result.Title != "" || result.Artist != "") {
			if _, ok := provider.OriginalStrength(req.Title, req.Artist, provider.TrackResult{Title: result.Title, Artist: result.Artist}); !ok {
				_ = os.Remove(result.FilePath)
				return &Result{ItemID: req.ItemID, Success: false, Error: fmt.Sprintf("%s: archivo no es la cancion original", name)}
			}
		}
		// Providers like amazon hand back an encrypted/DRM file (.m4a) with a
		// decryption key. If we can decrypt it into a playable file, serve that
		// (real, high-quality audio). Only when no key/ffmpeg is available do we
		// treat it as a failure and let another provider try.
		if result.Encrypted && result.DecryptionKey != "" {
			if dec, derr := decryptStream(result.FilePath, result.DecryptionKey, outDir, result.OutputExtension); derr == nil && dec != "" {
				_ = os.Remove(result.FilePath)
				dec = o.applyQuality(req.ItemID, dec, outDir, req.Quality)
				dec = finalizeDownloadFile(outDir, req.ItemID, dec)
				cooldown.MarkOpOk(name, downloadCooldownOp)
				o.tracker.SetOutputPath(req.ItemID, dec)
				return &Result{ItemID: req.ItemID, Success: true, Provider: name, FilePath: dec, Encrypted: false}
			} else if FFmpegPath() == "" && result.FilePath != "" {
				// No CLI ffmpeg (e.g. Android). Keep the encrypted file on disk
				// and hand it to the client so it can decrypt via ffmpeg-kit.
				o.tracker.SetEncryptedOutput(req.ItemID, result.FilePath, result.DecryptionKey, result.OutputExtension)
				cooldown.MarkOpOk(name, downloadCooldownOp)
				return &Result{ItemID: req.ItemID, Success: true, Provider: name, FilePath: result.FilePath, Encrypted: true, ClientDecrypt: true, DecryptionKey: result.DecryptionKey, OutputExtension: result.OutputExtension}
			}
			// Fall through to rejection (ffmpeg present but decrypt failed).
		}
		if result.Encrypted {
			_ = os.Remove(result.FilePath)
			return &Result{ItemID: req.ItemID, Success: false, Error: fmt.Sprintf("%s: stream encriptado no reproducible", name)}
		}
		result.FilePath = o.applyQuality(req.ItemID, result.FilePath, outDir, req.Quality)
		result.FilePath = finalizeDownloadFile(outDir, req.ItemID, result.FilePath)
		cooldown.MarkOpOk(name, downloadCooldownOp)
		o.tracker.SetOutputPath(req.ItemID, result.FilePath)
		return &Result{ItemID: req.ItemID, Success: true, Provider: name, FilePath: result.FilePath, Encrypted: false}
	}

	// Native provider: resolve a stream URL and download it to disk.
	streamURL, err := p.GetStreamURL(trackID, qualityForProvider(p, req.Quality))
	if err != nil || streamURL == "" {
		if err != nil {
			cooldown.MarkOpError(name, downloadCooldownOp, err.Error())
		}
		return &Result{ItemID: req.ItemID, Success: false, Error: fmt.Sprintf("%s: sin stream", name)}
	}
	if outDir != "" {
		filePath, derr := downloadToFile(streamURL, outDir, req, title, artist, func(done, total int64) {
			if total > 0 {
				o.tracker.Update(req.ItemID, StatusDownloading, 0.3+float64(done)/float64(total)*0.65)
			}
		})
		if derr != nil {
			return &Result{ItemID: req.ItemID, Success: false, Error: fmt.Sprintf("%s: %v", name, derr)}
		}
		filePath = o.applyQuality(req.ItemID, filePath, outDir, req.Quality)
		filePath = finalizeDownloadFile(outDir, req.ItemID, filePath)
		cooldown.MarkOpOk(name, downloadCooldownOp)
		o.tracker.SetOutputPath(req.ItemID, filePath)
		return &Result{ItemID: req.ItemID, Success: true, Provider: name, FilePath: filePath, StreamURL: streamURL}
	}

	// No output dir configured: fall back to returning the stream URL
	// (compatible with the previous streaming-only behavior).
	o.tracker.SetOutputPath(req.ItemID, streamURL)
	cooldown.MarkOpOk(name, downloadCooldownOp)
	return &Result{ItemID: req.ItemID, Success: true, Provider: name, StreamURL: streamURL}
}

var (
	downloadDirGlobal string
	outputDirMu       sync.RWMutex
)

// Per-provider track resolution cache. Key = provider name + a stable identity
// (ISRC, cross-provider ids, or title|artist). This makes the often-slow
// resolve step (amazon showSearch / name searches) run only once per track
// instead of once per provider / repeated play — a general speedup that applies
// to every source.
var (
	resCacheMu    sync.Mutex
	resCache      = map[string]map[string][3]string{}
	resCacheOrder []struct{ provider, key string }
)

const resCacheMaxKeys = 4000

// cachedResolve returns the cached resolution (trackID, title, artist) when
// available; otherwise resolves via resolveProviderTrackID and caches the
// result. Empty [key] disables caching (nothing stable to key on).
func cachedResolve(p provider.Provider, name, key string, req Request) (string, string, string) {
	if key != "" {
		resCacheMu.Lock()
		if m, ok := resCache[name]; ok {
			if r, ok2 := m[key]; ok2 {
				resCacheMu.Unlock()
				return r[0], r[1], r[2]
			}
		}
		resCacheMu.Unlock()
	}
	id, title, artist := resolveProviderTrackID(p, name, req)
	if key != "" && id != "" {
		resCacheMu.Lock()
		if len(resCacheOrder) >= resCacheMaxKeys {
			// Drop the oldest entries so the cache stays bounded.
			for len(resCacheOrder) >= resCacheMaxKeys/2 {
				old := resCacheOrder[0]
				resCacheOrder = resCacheOrder[1:]
				if m, ok := resCache[old.provider]; ok {
					delete(m, old.key)
					if len(m) == 0 {
						delete(resCache, old.provider)
					}
				}
			}
		}
		m := resCache[name]
		if m == nil {
			m = map[string][3]string{}
			resCache[name] = m
		}
		if _, exists := m[key]; !exists {
			m[key] = [3]string{id, title, artist}
			resCacheOrder = append(resCacheOrder, struct{ provider, key string }{name, key})
		}
		resCacheMu.Unlock()
	}
	return id, title, artist
}

// SetGlobalOutputDir stores the user's download dir (synced from Flutter).
func SetGlobalOutputDir(dir string) {
	outputDirMu.Lock()
	defer outputDirMu.Unlock()
	downloadDirGlobal = dir
}

// GlobalOutputDir returns the current global download dir.
func GlobalOutputDir() string {
	outputDirMu.RLock()
	defer outputDirMu.RUnlock()
	return downloadDirGlobal
}

// effectiveQuality maps quality labels to a canonical set understood by extensions.
func effectiveQuality(q string) string {
	if q == "" {
		return "LOSSLESS"
	}
	switch strings.ToUpper(q) {
	case "LOSSLESS", "HI_RES", "FLAC":
		return "LOSSLESS"
	case "MP3_128", "128":
		return "MP3_128"
	default:
		return strings.ToUpper(q)
	}
}

// qualityForProvider picks a quality token the given provider actually
// recognizes. Extensions declare qualityOptions in their manifest; when the
// requested quality isn't one of them (a source provider's token that doesn't
// map to this provider), it uses the extension's own highest quality — mirroring
// the reference middleware's per-provider quality selection.
func qualityForProvider(p provider.Provider, requested string) string {
	if ep, ok := p.(*provider.ExtensionProvider); ok {
		opts := ep.QualityOptions()
		if len(opts) > 0 {
			req := strings.TrimSpace(requested)
			if req != "" {
				for _, o := range opts {
					if strings.EqualFold(strings.TrimSpace(o), req) {
						return o // canonical id the extension recognizes
					}
				}
			}
			return opts[0] // fall back to the extension's best quality
		}
	}
	return effectiveQuality(requested)
}

// classifyVerificationError reports whether an error message indicates the
// provider needs a signed-session / Cloudflare challenge to be completed. These
// are surfaced as verification_required so the client can open the modal instead
// of failing silently (the reference middleware pauses fallback on these).
func classifyVerificationError(errMsg string) string {
	if errMsg == "" {
		return ""
	}
	e := strings.ToLower(errMsg)
	for _, marker := range []string{
		"verification_required", "verify_required", "verification required",
		"needs verification", "needs_verification", "challenge", "cloudflare",
		"captcha", "signed session", "session not verified", "session expired",
		"zarz", "not verified",
	} {
		if strings.Contains(e, marker) {
			return "verification_required"
		}
	}
	return ""
}

// resolveProviderTrackID maps a track request to a provider-specific track id
// using the richest signal available, in order of strength:
//  1. the provider that OWNS the item id (source provider) uses req.TrackID directly;
//  2. any cross-provider id already known (spotify/deezer/tidal/qobuz) via GetTrack;
//  3. ISRC lookup (strong, unambiguous);
//  4. strict title+artist search, keeping only the original track.
func resolveProviderTrackID(p provider.Provider, name string, req Request) (string, string, string) {
	title, artist := req.Title, req.Artist

	if name == req.Provider && req.TrackID != "" {
		// The owner provider receives its NATIVE id: feed items carry a
		// prefixed id ("tidal:123", "spotify:abc") that the extension's JS
		// does not understand. Mirror the reference middleware's
		// trimKnownProviderPrefix before handing it to the extension.
		return stripTrackPrefix(req.TrackID), title, artist
	}

	// Cross-provider ids: resolve them if the provider knows the id.
	for _, cid := range []string{req.SpotifyID, req.DeezerID, req.TidalID, req.QobuzID} {
		if cid == "" || strings.HasPrefix(cid, "deezer:") || strings.HasPrefix(cid, "spotify:") {
			continue
		}
		if t, err := p.GetTrack(cid); err == nil && t != nil {
			return t.ID, t.Title, t.Artist
		}
	}

	// Providers like amazon expose checkAvailability, which resolves the ASIN
	// via their signed /resolve route (using the verified session) or SongLink
	// instead of an anonymous web search that returns a login dialog -> zero
	// results. Prefer it before falling back to a name search.
	if ep, ok := p.(*provider.ExtensionProvider); ok {
		// Feed items don't always carry explicit cross-provider ids, but the
		// source provider's TrackID IS the native id for that source. Derive the
		// correct one so amazon can resolve via Deezer/Spotify/ISRC no matter
		// which feed produced the track (Spotify feed -> 22-char id, deezer feed
		// -> numeric id, tidal -> numeric id, amazon -> ASIN).
		spotifyID := req.SpotifyID
		deezerID := req.DeezerID
		tidalID := req.TidalID
		qobuzID := req.QobuzID
		// Feed items only carry the source provider's TrackID, but extensions
		// resolve via their own native id — so derive the right cross-provider
		// id from the TrackID shape (spotify=22 base62, deezer/tidal/qobuz=
		// numeric) so amazon & friends can resolve from ANY feed, exactly like
		// the reference middleware derives these ids for CheckAvailability.
		switch {
		case req.Provider == "spotify" || req.Provider == "spotify-web":
			if spotifyID == "" && provider.IsSpotifyID(stripTrackPrefix(req.TrackID)) {
				spotifyID = stripTrackPrefix(req.TrackID)
			}
		case req.Provider == "deezer" || req.Provider == "deezer-web":
			if deezerID == "" && provider.IsNumericID(stripTrackPrefix(req.TrackID)) {
				deezerID = stripTrackPrefix(req.TrackID)
			}
		case req.Provider == "tidal" || req.Provider == "tidal-web":
			if tidalID == "" && provider.IsNumericID(stripTrackPrefix(req.TrackID)) {
				tidalID = stripTrackPrefix(req.TrackID)
			}
		case req.Provider == "qobuz" || req.Provider == "qobuz-web":
			if qobuzID == "" && provider.IsNumericID(stripTrackPrefix(req.TrackID)) {
				qobuzID = stripTrackPrefix(req.TrackID)
			}
		}
		if id, found := ep.CheckAvailability(req.ISRC, req.Title, req.Artist, spotifyID, deezerID, tidalID, qobuzID, req.DurationMS); found && id != "" {
			return id, title, artist
		}
		// amazon's anonymous name/ISRC search always returns a login dialog
		// (zero results) and is very slow, burning the RPC timeout before the
		// fallback reaches providers that actually yield a stream. If amazon
		// cannot resolve via its signed /resolve / SongLink route, bail out
		// immediately and let the next provider take over.
		if name == "amazon" {
			return "", title, artist
		}
	}

	if req.ISRC != "" {
		if t, err := p.GetTrackByISRC(req.ISRC); err == nil && t != nil {
			return t.ID, t.Title, t.Artist
		}
	}

	if title != "" {
		if results, err := p.SearchTracks(title+" "+artist, 8); err == nil && len(results) > 0 {
			// Only resolve the ORIGINAL track (strong artist + title, no
			// remix/live/cover variants) so a fallback never pulls a different song.
			if best := provider.BestOriginal(title, artist, results); best != nil {
				return best.ID, best.Title, best.Artist
			}
		}
	}

	return "", title, artist
}

// confirmDownloadMatch reverse-verifies, before downloading, that a track id
// resolved for a NON-owner provider is the ORIGINAL requested track. It rejects
// only when we can CONFIRM it is a different song — an explicit ISRC mismatch
// or a weak title/artist match. A candidate with no ISRC at all (typical of
// soundcloud re-uploads) is NOT rejected, because soundcloud never exposes
// ISRC and rejecting it would make every soundcloud-only track unplayable;
// marked variants (remix/live/cover) are already filtered upstream by
// RankOriginalCandidates.
// durationTolerance bounds how much a candidate's length may diverge from the
// requested track before it is rejected. A cover, remix, extended or acoustic
// version of the "same" song almost always differs by more than this from the
// album version, so an unusually long/short match is a strong wrong-version
// signal even when title/artist happen to align.
func durationMatches(queryDurationMS, got int) bool {
	if queryDurationMS <= 0 || got <= 0 {
		return true
	}
	diff := queryDurationMS - got
	if diff < 0 {
		diff = -diff
	}
	tol := queryDurationMS / 4
	if tol < 20000 {
		tol = 20000
	}
	return diff <= tol
}

func confirmDownloadMatch(p provider.Provider, trackID, isrc, queryTitle, queryArtist string, queryDurationMS int) bool {
	t, err := p.GetTrack(trackID)
	if err != nil || t == nil {
		return true
	}
	if isrc != "" && t.ISRC != "" && !strings.EqualFold(strings.ToUpper(isrc), strings.ToUpper(t.ISRC)) {
		return false
	}
	if !durationMatches(queryDurationMS, t.Duration) {
		return false
	}
	if queryTitle == "" {
		return true
	}
	if _, ok := provider.OriginalStrength(queryTitle, queryArtist, *t); ok {
		return true
	}
	if t.ISRC != "" {
		if it, err := p.GetTrackByISRC(t.ISRC); err == nil && it != nil {
			if _, ok := provider.OriginalStrength(queryTitle, queryArtist, *it); ok {
				return true
			}
		}
	}
	return false
}

// stripTrackPrefix removes a KNOWN source prefix ("tidal:", "spotify:",
// "deezer:", "qobuz:", "amazon:", ...) from a feed item's id so provider
// GetTrack calls receive the raw native id the extension understands. Only
// known prefixes are stripped — a URL-shaped id ("https://...") or any other
// colon-bearing value is passed through untouched, mirroring the reference
// middleware's trimKnownProviderPrefix behavior.
func stripTrackPrefix(id string) string {
	i := strings.IndexByte(id, ':')
	if i <= 0 || i >= len(id)-1 {
		return id
	}
	switch strings.ToLower(id[:i]) {
	case "spotify", "deezer", "tidal", "qobuz", "amazon", "soundcloud", "apple", "youtube":
		return id[i+1:]
	}
	return id
}

var invalidFileChars = regexp.MustCompile(`[<>:"/\\|?*\x00-\x1F]`)

func sanitizeFilename(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return "unknown"
	}
	s = invalidFileChars.ReplaceAllString(s, "_")
	s = strings.TrimRight(s, ". ")
	if s == "" {
		return "unknown"
	}
	return s
}

// finalizeDownloadFile renames a freshly produced download/decrypt file from its
// temporary ".tmp." name to a clean {itemID}{ext} basename. The winner of the
// parallel race then has a stable, reusable name (StreamCacheFile matches it)
// and stays clearly distinct from the partial ".tmp." companions left by other
// candidates. Files already clean are returned untouched.
func finalizeDownloadFile(outDir, itemID, filePath string) string {
	if filePath == "" {
		return ""
	}
	ext := filepath.Ext(filePath)
	if ext == "" {
		return filePath
	}
	clean := filepath.Join(outDir, sanitizeFilename(itemID)+ext)
	if clean == filePath {
		return filePath
	}
	_ = os.Remove(clean)
	if err := os.Rename(filePath, clean); err == nil {
		return clean
	}
	return filePath
}

// StreamCacheFile returns the path of an already-produced stream-cache file for
// itemID (the same basename the download pipeline writes via sanitizeFilename),
// or "" if none exists. Letting repeated plays reuse the previously downloaded
// file makes the second invitation instant instead of re-downloading and
// re-converting from scratch.
func StreamCacheFile(dir, itemID string) string {
	if dir == "" || itemID == "" {
		return ""
	}
	base := sanitizeFilename(itemID) + "."
	entries, err := os.ReadDir(dir)
	if err != nil {
		return ""
	}
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		if !strings.HasPrefix(e.Name(), base) {
			continue
		}
		// Skip in-flight partial downloads. With parallel download plans several
		// providers may converge on the same itemId simultaneously; each writes
		// to a unique ".tmp."-suffixed file and only the winner keeps a clean
		// final file, so a partial/aborted companion must never be served or
		// treated as a complete cache entry.
		if strings.Contains(e.Name(), ".tmp.") {
			continue
		}
		full := filepath.Join(dir, e.Name())
		// Only serve files media_kit can actually decode. A stale/protected
		// file (e.g. an encrypted mp4 left with a .flac name) would reopen
		// forever and block playback, so invalid files are deleted and the
		// next tap re-downloads a fresh, verified copy.
		if isPlayableCachedFile(full) {
			return full
		}
		_ = os.Remove(full)
	}
	return ""
}

// isPlayableCachedFile validates that [path] holds an audio file media_kit can
// decode. The file's extension must MATCH the actual container: providers have
// produced mp4 containers labeled .flac (encrypted or with corrupt flac frames)
// that decode into silence/errors, and re-serving those would block playback
// forever. mp4/m4a files are additionally rejected when they carry a protection
// scheme (sinf/enca/encv) or a common encryption brand (cmfc/cenc) — those need
// a key + ffmpeg and can never decode inside the player.
func isPlayableCachedFile(path string) bool {
	ext := strings.ToLower(strings.TrimPrefix(filepath.Ext(path), "."))
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	head := make([]byte, 16)
	n, err := io.ReadFull(f, head)
	if err != nil && err != io.EOF && err != io.ErrUnexpectedEOF {
		return false
	}
	head = head[:n]
	switch ext {
	case "flac":
		return bytes.HasPrefix(head, []byte("fLaC"))
	case "mp3":
		return bytes.HasPrefix(head, []byte("ID3")) ||
			(len(head) >= 2 && head[0] == 0xFF && head[1]&0xE0 == 0xE0)
	case "ogg", "opus":
		return bytes.HasPrefix(head, []byte("OggS"))
	case "wav":
		return bytes.HasPrefix(head, []byte("RIFF"))
	case "m4a", "mp4", "aac", "m4b":
		if len(head) < 8 || !bytes.HasPrefix(head[4:], []byte("ftyp")) {
			return false
		}
		if bytes.Contains(head, []byte("cmfc")) || bytes.Contains(head, []byte("cenc")) {
			return false
		}
		return !fileContainsAny(path, []byte("sinf"), []byte("enca"), []byte("encv"))
	}
	return false
}

// fileContainsAny reports whether any needle occurs anywhere in the file,
// scanning in bounded 64KiB chunks (with overlap) so large cached files are
// checked without being loaded fully into memory.
func fileContainsAny(path string, needles ...[]byte) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	maxNeedle := 0
	for _, needle := range needles {
		if len(needle) > maxNeedle {
			maxNeedle = len(needle)
		}
	}
	if maxNeedle == 0 {
		return false
	}
	const chunkSize = 64 * 1024
	buf := make([]byte, chunkSize+maxNeedle)
	carry := 0
	for {
		n, err := f.Read(buf[carry:])
		total := carry + n
		if total > 0 {
			for _, needle := range needles {
				if bytes.Contains(buf[:total], needle) {
					return true
				}
			}
		}
		if err != nil {
			return false
		}
		keep := maxNeedle - 1
		if total >= keep {
			copy(buf, buf[total-keep:total])
			carry = keep
		} else {
			carry = total
		}
	}
}

// detectExt infers a file extension from a stream URL's query or path.
func detectExt(urlStr string) string {
	lower := strings.ToLower(urlStr)
	switch {
	case strings.Contains(lower, ".flac"):
		return ".flac"
	case strings.Contains(lower, ".mp3"):
		return ".mp3"
	case strings.Contains(lower, ".m4a"):
		return ".m4a"
	case strings.Contains(lower, ".opus"):
		return ".opus"
	case strings.Contains(lower, ".ogg"):
		return ".ogg"
	default:
		return ".mp3"
	}
}

// downloadToFile streams [url] to disk under [outDir] using a temp file +
// atomic rename, reporting progress via [onProgress].
func downloadToFile(url, outDir string, req Request, title, artist string, onProgress func(done, total int64)) (string, error) {
	if err := os.MkdirAll(outDir, 0755); err != nil {
		return "", err
	}

	client := &http.Client{Timeout: 0}
	resp, err := client.Get(url)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("HTTP %d al obtener stream", resp.StatusCode)
	}

	ext := detectExt(url)
	// Prefer a file named {trackID}{ext} so the Flutter player can find it.
	base := req.TrackID
	if base == "" {
		base = req.ItemID
	}
	dest := filepath.Join(outDir, sanitizeFilename(base)+ext)

	tmp, err := os.CreateTemp(outDir, "dl-*"+ext)
	if err != nil {
		return "", err
	}
	tmpPath := tmp.Name()
	defer func() {
		if _, statErr := os.Stat(tmpPath); statErr == nil {
			os.Remove(tmpPath)
		}
	}()

	var done int64
	buf := make([]byte, 64*1024)
	for {
		n, rerr := resp.Body.Read(buf)
		if n > 0 {
			if _, werr := tmp.Write(buf[:n]); werr != nil {
				tmp.Close()
				return "", werr
			}
			done += int64(n)
			onProgress(done, resp.ContentLength)
		}
		if rerr == io.EOF {
			break
		}
		if rerr != nil {
			tmp.Close()
			return "", rerr
		}
	}
	tmp.Close()

	if err := os.Rename(tmpPath, dest); err != nil {
		// Cross-device rename fallback.
		if in, inErr := os.Open(tmpPath); inErr == nil {
			out, outErr := os.Create(dest)
			if outErr == nil {
				_, _ = io.Copy(out, in)
				out.Close()
				in.Close()
				os.Remove(tmpPath)
			} else {
				in.Close()
				return "", outErr
			}
		} else {
			return "", inErr
		}
	}

	_ = title
	_ = artist
	return dest, nil
}

// ResolveVideoURL resolves a direct video stream URL for [trackID] at the
// requested quality height. Prefers the YouTube provider; falls back to the
// extension provider's video-capable provider if available.
func (o *Orchestrator) ResolveVideoURL(trackID, quality string) (string, error) {
	if p := o.providers.Get("youtube"); p != nil {
		if yc, ok := p.(*youtube.Client); ok {
			return yc.GetVideoURL(trackID, quality)
		}
	}
	// Fallback: try GetStreamURL (audio) so video download degrades gracefully.
	return o.resolveStreamURL(trackID, quality)
}

// resolveStreamURL returns a stream URL for a track from any registered provider.
func (o *Orchestrator) resolveStreamURL(trackID, quality string) (string, error) {
	for _, name := range o.fallbackOrder {
		if cooldown.IsCooledOp(name, downloadCooldownOp) {
			continue
		}
		p := o.providers.Get(name)
		if p == nil {
			continue
		}
		if url, err := p.GetStreamURL(trackID, quality); err == nil && url != "" {
			cooldown.MarkOpOk(name, downloadCooldownOp)
			return url, nil
		}
	}
	return "", fmt.Errorf("no provider produced a stream URL")
}

// WriteURLToFile downloads [url] to [path] using the same temp+rename logic.
func (o *Orchestrator) WriteURLToFile(url, path string) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	client := &http.Client{Timeout: 0}
	resp, err := client.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("HTTP %d al obtener stream", resp.StatusCode)
	}
	tmp, err := os.CreateTemp(filepath.Dir(path), "dl-*")
	if err != nil {
		return err
	}
	tmpPath := tmp.Name()
	defer os.Remove(tmpPath)
	buf := make([]byte, 256*1024)
	for {
		n, rerr := resp.Body.Read(buf)
		if n > 0 {
			if _, werr := tmp.Write(buf[:n]); werr != nil {
				tmp.Close()
				return werr
			}
		}
		if rerr == io.EOF {
			break
		}
		if rerr != nil {
			tmp.Close()
			return rerr
		}
	}
	tmp.Close()
	return os.Rename(tmpPath, path)
}
