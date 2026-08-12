package download

import (
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
	SpotifyID string `json:"spotifyId,omitempty"`
	DeezerID  string `json:"deezerId,omitempty"`
	TidalID   string `json:"tidalId,omitempty"`
	QobuzID   string `json:"qobuzId,omitempty"`
	DurationMS int   `json:"durationMs,omitempty"`
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
	ClientDecrypt    bool   `json:"clientDecrypt,omitempty"`
	DecryptionKey    string `json:"decryptionKey,omitempty"`
	OutputExtension  string `json:"outputExtension,omitempty"`
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

// maxFallbackDuration bounds how long the multi-provider fallback may keep
// starting new attempts. The Android RPC channel times out getStreamPackage
// after 60s, so staying well under it lets the orchestrator return a
// structured error (errorType/service) instead of being killed mid-flight.
const maxFallbackDuration = 50 * time.Second

// NewOrchestrator creates a download orchestrator with fallback chain.
func NewOrchestrator(reg *provider.Registry) *Orchestrator {
	return &Orchestrator{
		providers:   reg,
		tracker:     NewTracker(),
		active:      make(map[string]bool),
		concurrency: make(chan struct{}, maxConcurrentDownloads),
		fallbackOrder: buildFallbackOrder(reg),
	}
}

// preferredStreamOrder lists streaming providers best-first. It includes the
// extension-registered (-web) names because the native providers they replace
// (qobuz/tidal/apple/spotify) are never registered — using the native names
// would silently skip real sources during fallback.
var preferredStreamOrder = []string{
	"amazon", "deezer", "qobuz-web", "tidal-web",
	"soundcloud", "apple-music", "spotify-web", "youtube", "pandora",
	// ytmusic-spotiflac is the JS-based YouTube fallback (no yt-dlp needed),
	// so it works on mobile/desktop alike. Its getDownloadUrl() returns null,
	// so it only serves audio through the download pipeline — making it the
	// reliable universal last resort when every other provider has no stream.
	"ytmusic-spotiflac",
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

	// Enrich the request with the source provider's own ISRC when the feed item
	// didn't carry one (e.g. tidal/apple/qobuz feeds). Providers like amazon
	// resolve via SongLink using the ISRC, so a track that reached the app from
	// ANY feed can still be served the same FLAC as the Spotify feed instead of
	// falling back to a lossy soundcloud/ytmusic stream. One cached getTrack
	// call is far cheaper than the multi-provider search chain it unblocks.
	if req.ISRC == "" && req.Provider != "" && req.TrackID != "" {
		if sp := o.providers.Get(req.Provider); sp != nil {
			if t, err := sp.GetTrack(stripTrackPrefix(req.TrackID)); err == nil && t != nil && t.ISRC != "" {
				req.ISRC = t.ISRC
			}
		}
	}

	var lastErr string
	var encryptedSeen bool
	var verificationService string
	fallbackStart := time.Now()
	for _, name := range providersToTry {
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
		if cooldown.IsCooled(name) {
			continue
		}

		o.tracker.Update(req.ItemID, StatusDownloading, 0.1)

		trackID, title, artist := resolveProviderTrackID(p, name, req)
		if trackID == "" {
			continue
		}
		o.tracker.SetTrackInfo(req.ItemID, title, artist)

		// Full extension download pipeline (writes file to disk, reports real progress).
		if ep, ok := p.(*provider.ExtensionProvider); ok && outDir != "" {
			o.tracker.Update(req.ItemID, StatusDownloading, 0.2)
			// The extension download() expects a full destination path, not a
			// directory. Build a basename from the track id (or title) so each
			// stream cache file has a proper, non-colliding name; the extension
			// corrects the final extension to match the actual format.
			extBase := req.ItemID
			if extBase == "" {
				extBase = title + " - " + artist
			}
			extDest := filepath.Join(outDir, sanitizeFilename(extBase)+".tmp")
			result := ep.Download(trackID, qualityForProvider(p, req.Quality), extDest, func(percent int) {
				o.tracker.Update(req.ItemID, StatusDownloading, 0.2+float64(percent)/100.0*0.7)
			})
			if !result.Success {
				lastErr = result.Error
				cooldown.MarkError(name, result.Error)
				if vt := classifyVerificationError(result.Error); vt != "" {
					// Don't abort the fallback here: a later provider (e.g.
					// soundcloud, ytmusic-spotiflac) may still yield a stream.
					// Remember the first verification-needing provider so we can
					// surface it only if every provider ends up streamless.
					verificationService = name
					o.tracker.SetError(req.ItemID, "verification required")
					lastErr = "Download failed: " + result.Error
					continue
				}
				continue
			}
			if result.FilePath == "" {
				lastErr = fmt.Sprintf("%s: sin archivo", name)
				continue
			}
			{
				// Double-check the downloaded file is the ORIGINAL song. The
				// extension reports the real title/artist of what it put on
				// disk; if they don't strongly match the request, discard it
				// and let a downstream provider try instead of serving a wrong
				// version (cover/remix/wrong artist).
				if req.Title != "" && (result.Title != "" || result.Artist != "") {
					if _, ok := provider.OriginalStrength(req.Title, req.Artist, provider.TrackResult{Title: result.Title, Artist: result.Artist}); !ok {
						lastErr = fmt.Sprintf("%s: archivo no es la cancion original", name)
						_ = os.Remove(result.FilePath)
						continue
					}
				}
				// Providers like amazon hand back an encrypted/DRM file
				// (.m4a) with a decryption key. If we can decrypt it into a
				// playable file, serve that (real, high-quality audio). Only when
				// no key/ffmpeg is available do we treat it as a failure and let
				// the loop try the next provider.
				if result.Encrypted && result.DecryptionKey != "" {
				if dec, derr := decryptStream(result.FilePath, result.DecryptionKey, outDir, result.OutputExtension); derr == nil && dec != "" {
					_ = os.Remove(result.FilePath)
					dec = o.applyQuality(req.ItemID, dec, outDir, req.Quality)
					cooldown.MarkOk(name)
					return &Result{
						ItemID:    req.ItemID,
						Success:   true,
						Provider:  name,
						FilePath:  dec,
						Encrypted: false,
					}
					} else if FFmpegPath() == "" && result.FilePath != "" {
						// No CLI ffmpeg (e.g. Android). Keep the encrypted file
						// on disk and hand it to the client so it can decrypt
						// via ffmpeg-kit; this is the real, high-quality source
						// (amazon FLAC) and rejecting it would leave nothing.
						o.tracker.SetEncryptedOutput(req.ItemID, result.FilePath, result.DecryptionKey, result.OutputExtension)
						cooldown.MarkOk(name)
						return &Result{
							ItemID:          req.ItemID,
							Success:         true,
							Provider:        name,
							FilePath:        result.FilePath,
							Encrypted:       true,
							ClientDecrypt:   true,
							DecryptionKey:   result.DecryptionKey,
							OutputExtension: result.OutputExtension,
						}
					}
					// Fall through to rejection (ffmpeg present but decrypt failed).
				}
				if result.Encrypted {
					lastErr = fmt.Sprintf("%s: stream encriptado no reproducible", name)
					encryptedSeen = true
					_ = os.Remove(result.FilePath)
					continue
				}
				result.FilePath = o.applyQuality(req.ItemID, result.FilePath, outDir, req.Quality)
				cooldown.MarkOk(name)
				return &Result{
					ItemID:    req.ItemID,
					Success:   true,
					Provider:  name,
					FilePath:  result.FilePath,
					Encrypted: false,
				}
			}
		}

		// Native provider: resolve a stream URL and download it to disk.
		streamURL, err := p.GetStreamURL(trackID, qualityForProvider(p, req.Quality))
		if err != nil || streamURL == "" {
			lastErr = fmt.Sprintf("%s: sin stream", name)
			if err != nil {
				cooldown.MarkError(name, err.Error())
			}
			continue
		}
		if outDir != "" {
			filePath, derr := downloadToFile(streamURL, outDir, req, title, artist, func(done, total int64) {
				if total > 0 {
					o.tracker.Update(req.ItemID, StatusDownloading, 0.3+float64(done)/float64(total)*0.65)
				}
			})
			if derr != nil {
				lastErr = fmt.Sprintf("%s: %v", name, derr)
				continue
			}
			filePath = o.applyQuality(req.ItemID, filePath, outDir, req.Quality)
			cooldown.MarkOk(name)
			return &Result{
				ItemID:    req.ItemID,
				Success:   true,
				Provider:  name,
				FilePath:  filePath,
				StreamURL: streamURL,
			}
		}

		// No output dir configured: fall back to returning the stream URL
		// (compatible with the previous streaming-only behavior).
		o.tracker.SetOutputPath(req.ItemID, streamURL)
		cooldown.MarkOk(name)
		return &Result{
			ItemID:    req.ItemID,
			Success:   true,
			Provider:  name,
			StreamURL: streamURL,
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

var (
	downloadDirGlobal string
	outputDirMu       sync.RWMutex
)

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
		if cooldown.IsCooled(name) {
			continue
		}
		p := o.providers.Get(name)
		if p == nil {
			continue
		}
		if url, err := p.GetStreamURL(trackID, quality); err == nil && url != "" {
			cooldown.MarkOk(name)
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
