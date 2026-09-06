package gobackend

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/download"
	"github.com/zarz/bitly/go_backend/internal/streaming"
)

// streamFailCache remembers tracks whose stream resolution failed across every
// provider (the full fallback walk — 10-30s of provider probes, name searches
// and mirror attempts). Re-tapping the same track within the TTL returns the
// cached error in milliseconds instead of re-walking the whole chain for a
// result that just failed seconds ago. Short TTL + clear-on-success means a
// provider that recovers is retried soon.
var (
	streamFailMu    sync.Mutex
	streamFailCache = map[string]streamFailEntry{}
)

type streamFailEntry struct {
	at        time.Time
	err       string
	errorType string
	service   string
}

// streamFailMemoryTTL is how long a failure is honored within a live session
// (fast re-taps). streamFailDiskTTL is how long a failure survives restarts —
// long enough that a dead track (age-blocked video, all mirrors down) is not
// re-walked on every cold start, but short enough that a provider that comes
// back is retried soon. Verification-required failures are never persisted
// (completing the verification can make the track playable), only definitive
// "no source anywhere" results.
const (
	streamFailMemoryTTL = 90 * time.Second
	streamFailDiskTTL   = 20 * time.Minute
)

// streamFailPersistName is the JSON file kept inside the stream cache dir.
const streamFailPersistName = "stream_failures.json"

// streamFailPersistPathLocked derives the fail-cache file location from the
// live download dir (the same base streamCacheDirPath uses). Caller must hold
// streamFailMu.
func streamFailPersistPathLocked() string {
	base := downloadDir
	if base == "" {
		base = download.GlobalOutputDir()
	}
	if base == "" {
		return "" // no writable dir configured yet — skip persistence
	}
	return filepath.Join(base, ".stream_cache", streamFailPersistName)
}

// isTransientServerError reports whether [err] describes a temporary server
// failure (HTTP 5xx, gateway errors, timeouts) rather than a definitive "this
// track is not available anywhere" verdict. Transient failures must not be
// fail-cached: the source may recover (or the track may be servable by a
// verification-pending provider), so the next tap should re-attempt instead of
// instantly replaying a stale error.
func isTransientServerError(err string) bool {
	if err == "" {
		return false
	}
	e := strings.ToLower(err)
	for _, marker := range []string{
		"http 500", "http 501", "http 502", "http 503", "http 504",
		"http 505", "http 511",
		"bad gateway", "gateway timeout", "service unavailable",
		"temporarily unavailable", "connection reset", "connection refused",
		"connection timed out", "timeout", "timed out", "no route to host",
		"server error", "upstream", "overloaded",
	} {
		if strings.Contains(e, marker) {
			return true
		}
	}
	return false
}

// deezerCanServeByISRC reports whether deezer's PUBLIC metadata API resolves
// this exact ISRC — free, no signed session needed. When true, the only thing
// standing between the user and the song is their deezer session verification:
// the app should open the verification modal instead of showing a dead-end
// error, because completing it makes the song play.
func deezerCanServeByISRC(isrc string) bool {
	if isrc == "" || reg == nil {
		return false
	}
	p := reg.Get("deezer")
	if p == nil {
		return false
	}
	// A cooled deezer is silently skipped by the fallback walk (call() returns
	// nil, nil), which masks the VERIFY_REQUIRED it would surface. This probe
	// is the LAST chance before giving up: clear the cooldown (both buckets)
	// so it actually runs, and leave deezer un-cooled for the retry that
	// follows once the user completes the verification.
	cooldown.MarkOk(p.Name())
	cooldown.MarkOpOk(p.Name(), "download")
	t, err := p.GetTrackByISRC(isrc)
	return err == nil && t != nil && t.ID != ""
}

// streamFailKey builds a stable identity for a track: the strongest identifier
// wins (ISRC, then any cross-provider id, then the raw track id).
func streamFailKey(p ...string) string {
	for _, v := range p {
		if v != "" {
			return v
		}
	}
	return ""
}

func streamFailGet(key string) (streamFailEntry, bool) {
	streamFailMu.Lock()
	defer streamFailMu.Unlock()
	e, ok := streamFailCache[key]
	if ok && time.Since(e.at) <= streamFailMemoryTTL {
		return e, true
	}
	if ok {
		// Memory copy expired — fall through to disk (may still be within the
		// longer restart window).
		delete(streamFailCache, key)
	}
	// Try the persisted copy (survives app restarts). Load it into memory so
	// the next lookup doesn't hit disk again, and refresh its timestamp so the
	// live session honors it for the full memory TTL.
	e, ok = streamFailDiskGetLocked(key)
	if ok {
		e.at = time.Now()
		streamFailCache[key] = e
		return e, true
	}
	return streamFailEntry{}, false
}

func streamFailSet(key, err, errorType, service string) {
	if key == "" {
		return
	}
	// Verification-required errors are RECOVERABLE (the user can complete the
	// Cloudflare/signed-session challenge and the track becomes playable), so
	// they must not be cached at all — neither in memory nor on disk. A stale
	// entry would keep returning the old failure right after the user finishes
	// verifying, instead of retrying the provider that just became usable.
	lower := strings.ToLower(errorType)
	if lower == "verification_required" ||
		strings.Contains(strings.ToLower(err), "verify_required") ||
		strings.Contains(strings.ToLower(err), "verification required") {
		return
	}
	// Transient server errors (5xx from a provider's relay/API, timeouts,
	// gateway hiccups) are NOT definitive: the provider may recover seconds
	// later. Caching them makes every subsequent tap fail instantly with a
	// stale error (e.g. Tidal's relay 502-ing for one song while Deezer could
	// serve it after verification) — so never cache them, memory or disk.
	if isTransientServerError(err) {
		return
	}
	now := time.Now()
	entry := streamFailEntry{at: now, err: err, errorType: errorType, service: service}
	streamFailMu.Lock()
	streamFailCache[key] = entry
	// Persist only definitive failures (no source anywhere). Verification-
	// required errors must NOT be persisted: completing the verification can
	// make the track playable, and a stale disk entry would keep failing it.
	if errorType == "" || strings.ToLower(errorType) == "no_stream" {
		streamFailDiskSetLocked(key, entry)
	}
	streamFailMu.Unlock()
}

func streamFailClear(key string) {
	if key == "" {
		return
	}
	streamFailMu.Lock()
	defer streamFailMu.Unlock()
	delete(streamFailCache, key)
	streamFailDiskClearLocked(key)
}

// streamFailDiskGetLocked loads [key] from the persisted cache if it is still
// within streamFailDiskTTL. Caller must hold streamFailMu.
func streamFailDiskGetLocked(key string) (streamFailEntry, bool) {
	path := streamFailPersistPathLocked()
	if path == "" {
		return streamFailEntry{}, false
	}
	entries, err := streamFailDiskReadLocked(path)
	if err != nil {
		return streamFailEntry{}, false
	}
	e, ok := entries[key]
	if !ok {
		return streamFailEntry{}, false
	}
	if time.Since(e.at) > streamFailDiskTTL {
		return streamFailEntry{}, false
	}
	return e, true
}

// streamFailDiskSetLocked persists [entry] under [key]. Caller holds streamFailMu.
func streamFailDiskSetLocked(key string, entry streamFailEntry) {
	path := streamFailPersistPathLocked()
	if path == "" {
		return
	}
	entries, err := streamFailDiskReadLocked(path)
	if err != nil {
		entries = map[string]streamFailEntry{}
	}
	// Bounded size: keep the most recent 400 failures so the JSON never
	// grows unbounded on long browsing sessions.
	if len(entries) >= 400 && entries[key].at.IsZero() {
		oldestKey := ""
		oldest := time.Time{}
		for k, v := range entries {
			if oldestKey == "" || v.at.Before(oldest) {
				oldestKey = k
				oldest = v.at
			}
		}
		if oldestKey != "" {
			delete(entries, oldestKey)
		}
	}
	entries[key] = entry
	streamFailDiskWriteLocked(path, entries)
}

// streamFailDiskClearLocked removes [key] from the persisted cache. Caller
// holds streamFailMu.
func streamFailDiskClearLocked(key string) {
	path := streamFailPersistPathLocked()
	if path == "" {
		return
	}
	entries, err := streamFailDiskReadLocked(path)
	if err != nil {
		return
	}
	if _, ok := entries[key]; !ok {
		return
	}
	delete(entries, key)
	streamFailDiskWriteLocked(path, entries)
}

// streamFailDiskEntry is the JSON-safe (exported fields) form of a persisted
// failure. encoding/json ignores unexported fields, so the live entry type
// cannot be marshaled directly.
type streamFailDiskEntry struct {
	At        time.Time `json:"at"`
	Err       string    `json:"err"`
	ErrorType string    `json:"errorType"`
	Service   string    `json:"service"`
}

// streamFailDiskReadLocked reads the persisted fail cache from disk. Caller
// must hold streamFailMu.
func streamFailDiskReadLocked(path string) (map[string]streamFailEntry, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var raw map[string]streamFailDiskEntry
	if err := json.Unmarshal(data, &raw); err != nil {
		return nil, err
	}
	out := make(map[string]streamFailEntry, len(raw))
	for k, v := range raw {
		out[k] = streamFailEntry{at: v.At, err: v.Err, errorType: v.ErrorType, service: v.Service}
	}
	return out, nil
}

// streamFailDiskWriteLocked writes the persisted fail cache to disk
// atomically (temp + rename). Caller holds streamFailMu.
func streamFailDiskWriteLocked(path string, entries map[string]streamFailEntry) {
	if path == "" {
		return
	}
	encodable := make(map[string]streamFailDiskEntry, len(entries))
	for k, v := range entries {
		if time.Since(v.at) <= streamFailDiskTTL {
			encodable[k] = streamFailDiskEntry{
				At:        v.at,
				Err:       v.err,
				ErrorType: v.errorType,
				Service:   v.service,
			}
		}
	}
	data, err := json.Marshal(encodable)
	if err != nil {
		return
	}
	tmp := path + ".tmp"
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return
	}
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		return
	}
	_ = os.Rename(tmp, path)
}

// streamFailErrorJSON rebuilds the RPC error payload from a cached entry.
func streamFailErrorJSON(e streamFailEntry) string {
	mp := map[string]interface{}{"error": e.err}
	if e.errorType != "" {
		mp["errorType"] = e.errorType
	}
	if e.service != "" {
		mp["service"] = e.service
	}
	data, _ := json.Marshal(mp)
	return string(data)
}

// =========================================================================
// STREAMING
// =========================================================================

func GetStreamURL(payload string) string {
	var params struct {
		ProviderName string `json:"providerName"`
		TrackID      string `json:"trackID"`
		Quality      string `json:"quality"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	p := reg.Get(params.ProviderName)
	if p == nil {
		return jsonErrorStr("proveedor no encontrado")
	}
	url, err := p.GetStreamURL(params.TrackID, params.Quality)
	if err != nil {
		return jsonError(err)
	}
	return `{"url":"` + url + `"}`
}

// StartStreamingServer starts an HTTP proxy for audio streaming (desktop).
func StartStreamingServer(port int) string {
	if streamer == nil {
		streamer = streaming.NewStreamer()
	}
	addr, err := streamer.StartServer(port)
	if err != nil {
		return jsonError(err)
	}
	return `{"url":"` + addr + `"}`
}

// StopStreamingServer stops the streaming HTTP server.
func StopStreamingServer() string {
	if streamer == nil {
		return `{"ok":true}`
	}
	if err := streamer.StopServer(); err != nil {
		return jsonError(err)
	}
	return `{"ok":true}`
}

// GetStreamPackage returns a complete stream package: audio URL + metadata + lyrics + cover.
// Hace fallback entre providers si el especificado no tiene stream.
func GetStreamPackage(payload string) string {
	if reg == nil {
		return `{"error":"no inicializado"}`
	}
	var params struct {
		PreferredProvider string `json:"preferredProvider"`
		TrackID           string `json:"trackID"`
		Quality           string `json:"quality"`
		FetchLyrics       string `json:"fetchLyrics"`
		TrackName         string `json:"trackName"`
		ArtistName        string `json:"artistName"`
		ISRC              string `json:"isrc"`
		DurationMS        int    `json:"durationMs"`
		AllowFallback     bool   `json:"allowFallback"`
		// Cross-provider ids from detail views (album/artist/playlist). Detail
		// tracks carry these so ANY extension can resolve immediately via
		// CheckAvailability instead of a slow name search.
		SpotifyID string `json:"spotifyId"`
		DeezerID  string `json:"deezerId"`
		TidalID   string `json:"tidalId"`
		QobuzID   string `json:"qobuzId"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	fetchL := params.FetchLyrics == "true" || params.FetchLyrics == "1"

	// enrichISRC fills a missing ISRC from the source provider / cross-provider
	// ids so the fallback download below can match strictly (never serve a
	// same-title remix for a track whose exact ISRC is known; feeds often
	// deliver isrc=null). It runs ONLY on real playback (AllowFallback=true)
	// AFTER the fast streaming path has failed — the fast path resolves via
	// cross-provider ids alone, and running up to 7 sequential GetTrack calls
	// before it was the reason a first tap in search/feed took seconds even
	// though a direct stream existed.
	enrichISRC := func() {
		if params.ISRC != "" {
			return
		}
		enrich := func(pn string, id string) {
			if params.ISRC != "" || id == "" {
				return
			}
			// spotify-web can only resolve native Spotify IDs; feeding it a
			// deezer/tidal prefixed id ("deezer:3733293352") throws inside the
			// extension and wastes an API call.
			if pn == "spotify-web" && !download.IsSpotifyTrackID(id) {
				return
			}
			if p := reg.Get(pn); p != nil {
				if t, err := p.GetTrack(id); err == nil && t != nil && t.ISRC != "" {
					params.ISRC = t.ISRC
				}
			}
		}
		// Only the calls that can actually succeed: the source provider with its
		// OWN id, and spotify-web with a native Spotify id (its metadata carries
		// ISRC reliably). Cross-feeding another provider's id into the source
		// provider's GetTrack is a no-op that just burns latency.
		enrich(params.PreferredProvider, params.TrackID)
		enrich("spotify-web", params.SpotifyID)
		enrich("spotify-web", params.TrackID)
	}

	// Real playback (AllowFallback=true).
	//
	// FULL-STREAM providers (youtube/ytmusic/soundcloud/deezer) serve full-length
	// http audio: resolve it via identifiers (~1-2s, no slow name search) and play
	// instantly — media_kit streams it progressively.
	//
	// Preview/DRM providers (apple-music, spotify-web, amazon, qobuz, tidal) have
	// no usable direct stream (30s clips or encrypted files), so playback produces
	// the actual file (identifier-based + cached) exactly as before.
	if params.AllowFallback {
		// Fail fast: if this exact track just failed the full provider walk
		// (seconds ago), return the cached error immediately instead of walking
		// every provider + mirror again (10-30s) for a result that can't have
		// changed. Clear-on-success below keeps the window short and honest.
		failKey := streamFailKey(params.ISRC, params.SpotifyID, params.DeezerID, params.TidalID, params.QobuzID, params.TrackID)
		if failKey != "" {
			if cachedFail, hit := streamFailGet(failKey); hit {
				return streamFailErrorJSON(cachedFail)
			}
		}
		if streaming.IsFullStreamProvider(params.PreferredProvider) {
			url, name, err := streaming.StreamQuick(reg, params.PreferredProvider, params.TrackID, params.Quality, params.ISRC, params.SpotifyID, params.DeezerID, params.TidalID, params.QobuzID, params.TrackName, params.ArtistName)
			if err == nil && url != "" {
				streamFailClear(failKey)
				pkg := &streaming.StreamPackage{AudioURL: url, Provider: name, Quality: params.Quality}
				data, _ := json.Marshal(pkg)
				return string(data)
			}
			// The preferred provider HAS the exact track but needs its signed
			// session verified — return that verdict NOW (1-2s) so the client
			// opens the verification modal instead of a 10-30s fallback walk
			// that ends on the same error.
			if verr, ok := err.(*streaming.VerifyRequiredError); ok {
				return streamVerifyErrorJSON(verr)
			}
		}

		// When the preferred provider is a preview/DRM source (tidal, apple,
		// amazon, qobuz, spotify-web) it has no direct stream, but another
		// FULL-STREAM provider (deezer/soundcloud/ytmusic/youtube) may serve
		// the same exact track via its ISRC / cross-provider id in ~1-2s. Probe
		// them before committing to the slow download pipeline — this is what
		// makes a tidal/amazon track start playing in seconds instead of after
		// a full multi-provider download.
		if url, name, err := streaming.RescueStreamURL(reg, params.Quality, params.ISRC, params.SpotifyID, params.DeezerID, params.TidalID, params.QobuzID, params.TrackName, params.ArtistName); err == nil && url != "" {
			streamFailClear(failKey)
			pkg := &streaming.StreamPackage{AudioURL: url, Provider: name, Quality: params.Quality}
			data, _ := json.Marshal(pkg)
			return string(data)
		} else if verr, ok := err.(*streaming.VerifyRequiredError); ok {
			// The exact track was found on a full-stream provider but its
			// session is not verified. Fail fast: the client opens the modal
			// for [service]; completing it makes the song play. Skip the slow
			// fallback download — it would walk every provider (10-30s) and
			// end on the same verification verdict.
			return streamVerifyErrorJSON(verr)
		}

		// Fast path exhausted: enrich the ISRC now (only on real playback, only
		// after the direct-stream probes) so the fallback download matches the
		// exact track across providers instead of name-searching from scratch.
		enrichISRC()
		out := streamFallbackDownload(params.TrackID, params.Quality, params.PreferredProvider, params.TrackName, params.ArtistName, params.ISRC, params.DurationMS, params.SpotifyID, params.DeezerID, params.TidalID, params.QobuzID)
		if out.encrypted != nil {
			return streamEncryptedJSON(out.encrypted, params.PreferredProvider)
		}
		if out.fileURL != "" {
			streamFailClear(failKey)
			pkg := &streaming.StreamPackage{
				AudioURL: out.fileURL,
				Provider: "fallback",
				Quality:  params.Quality,
			}
			data, _ := json.Marshal(pkg)
			return string(data)
		}
		if out.err != nil {
			// Everything failed. Remember this exact track so the next tap
			// returns fast instead of re-walking all providers, then surface
			// the structured error (errorType/service names the provider that
			// actually needs verification, e.g. amazon VERIFY_REQUIRED).
			streamFailSet(failKey, out.err.Error(), out.errorType, out.service)
			return streamFallbackErrorJSON(out.err, out)
		}
	}

	pkg, err := streaming.GetStreamPackage(reg, lyricsClient, params.PreferredProvider, params.TrackID, params.Quality, fetchL, params.TrackName, params.ArtistName, params.ISRC, params.SpotifyID, params.DeezerID, params.TidalID, params.QobuzID)
	if err != nil && !params.AllowFallback {
		// Background preloads (feed/queue prefetch) skip the download fallback
		// so they don't trigger full audio downloads for every non-streamable
		// track. The player re-resolves with fallback when the user taps play.
		return jsonError(err)
	}
	if err != nil {
		// Last resort: only download-to-cache if the direct resolve above failed
		// (the AllowFallback fast-path already tried it once).
		out := streamFallbackDownload(params.TrackID, params.Quality, params.PreferredProvider, params.TrackName, params.ArtistName, params.ISRC, params.DurationMS, params.SpotifyID, params.DeezerID, params.TidalID, params.QobuzID)
		if out.encrypted != nil {
			return streamEncryptedJSON(out.encrypted, params.PreferredProvider)
		}
		if out.err != nil {
			// Surface the structured error (errorType/service) so the client can
			// open the right verification flow, not just the raw message.
			return streamFallbackErrorJSON(fmt.Errorf("%v; fallback: %v", err, out.err), out)
		}
		pkg = &streaming.StreamPackage{
			AudioURL: out.fileURL,
			Provider: "fallback",
			Quality:  params.Quality,
		}
	}
	data, _ := json.Marshal(pkg)
	return string(data)
}

// streamVerifyErrorJSON builds the RPC error payload for a fast verification
// verdict: the track exists on [verr.Service] but that provider's signed
// session must be completed before it can stream. The client reads
// errorType=verification_required + service to open the right modal.
func streamVerifyErrorJSON(verr *streaming.VerifyRequiredError) string {
	mp := map[string]interface{}{
		"error":     verr.Error(),
		"errorType": "verification_required",
		"service":   verr.Service,
	}
	data, _ := json.Marshal(mp)
	return string(data)
}

// streamFallbackErrorJSON builds the RPC error response for a failed fallback
// download, carrying the structured errorType/service so the client can react
// (e.g. open a Cloudflare verification modal for the provider that needs it).
func streamFallbackErrorJSON(err error, out *streamFallbackOutcome) string {
	mp := map[string]interface{}{"error": err.Error()}
	if out != nil {
		if out.errorType != "" {
			mp["errorType"] = out.errorType
		}
		if out.service != "" {
			mp["service"] = out.service
		}
	}
	data, _ := json.Marshal(mp)
	return string(data)
}

// streamEncryptedInfo carries an encrypted/DRM file that needs client-side
// decryption (e.g. amazon FLAC with a decryption key, when no CLI ffmpeg is
// available on the platform). The file is kept on disk.
type streamEncryptedInfo struct {
	FilePath    string
	Key         string
	OutputExt   string
	InputFormat string
}

// streamEncryptedJSON builds the RPC response telling the client an encrypted
// file is ready and must be decrypted (e.g. via ffmpeg-kit) before playback.
func streamEncryptedJSON(info *streamEncryptedInfo, provider string) string {
	mp := map[string]interface{}{
		"needsDecryption": true,
		"filePath":        info.FilePath,
		"decryptionKey":   info.Key,
		"outputExtension": info.OutputExt,
		"inputFormat":     info.InputFormat,
		"provider":        provider,
	}
	data, _ := json.Marshal(mp)
	return string(data)
}

// streamFallbackOutcome is the result of a fallback download: either a playable
// file URL, or an encrypted file for the client to decrypt, or an error.
type streamFallbackOutcome struct {
	fileURL   string
	encrypted *streamEncryptedInfo
	err       error
	// errorType classifies the failure (e.g. "verification_required") and
	// service names the provider involved, so the client can open the correct
	// Cloudflare verification flow instead of showing a generic error.
	errorType string
	service   string
}

// streamFallbackDownload downloads the audio for [trackID] into the stream
// cache directory using the same pipeline as an explicit download (extension
// download() or native stream URL → file on disk). Returns a playable file://
// URL that media_kit can open on every platform (desktop + Android), or — when
// the only source is an encrypted/DRM file needing ffmpeg that isn't available
// (Android) — the encrypted file so the client can decrypt via ffmpeg-kit.
func streamFallbackDownload(trackID, quality, provider, trackName, artistName, isrc string, durationMs int, spotifyID, deezerID, tidalID, qobuzID string) *streamFallbackOutcome {
	if downloadOrch == nil {
		return &streamFallbackOutcome{err: fmt.Errorf("descarga no disponible")}
	}
	if trackID == "" && trackName == "" && isrc == "" {
		return &streamFallbackOutcome{err: fmt.Errorf("sin identificador de track")}
	}
	outDir := streamCacheDirPath()
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		return &streamFallbackOutcome{err: err}
	}
	// Reuse a previously produced stream-cache file for the same track: the
	// first tap downloads+converts, later taps play the existing file instantly.
	if cached := download.StreamCacheFile(outDir, trackID); cached != "" {
		return &streamFallbackOutcome{fileURL: "file://" + filepath.ToSlash(cached)}
	}
	// Pass the item id but keep the source provider: the orchestrator uses it
	// ONLY on the provider that owns it (so amazon's ASIN isn't fed to deezer
	// etc.), and resolves every other provider via ISRC (then strict search).
	// This is what lets a feed item play back via the same extension that
	// produced it (e.g. amazon) instead of name-searching from scratch.
	res := downloadOrch.Download(download.Request{
		ItemID:     trackID,
		Title:      trackName,
		Artist:     artistName,
		Provider:   provider,
		ISRC:       isrc,
		TrackID:    trackID,
		Quality:    quality,
		OutputDir:  outDir,
		DurationMS: durationMs,
		SpotifyID:  spotifyID,
		DeezerID:   deezerID,
		TidalID:    tidalID,
		QobuzID:    qobuzID,
	})
	// Cache-only downloads must not leak into the download tracker: the Flutter
	// download UI polls getAllDownloadProgress and would otherwise record this
	// track as a real user download (DB row + "downloaded" badge).
	if downloadOrch.Progress() != nil {
		downloadOrch.Progress().Remove(trackID)
	}
	if res == nil || !res.Success || res.FilePath == "" {
		msg := "descarga fallida"
		if res != nil && res.Error != "" {
			msg = res.Error
		}
		out := &streamFallbackOutcome{err: fmt.Errorf("%s", msg)}
		if res != nil {
			out.errorType = res.ErrorType
			out.service = res.Service
		}
		// Last chance before giving up: when the walk ended with a GENERIC
		// failure (no provider surfaced a verification need — e.g. deezer was
		// skipped by the circuit breaker, which silently drops its result) but
		// deezer HAS this exact track by ISRC (public metadata API, no session
		// needed), the only missing piece is the user's deezer session
		// verification. Surface it so the app opens the modal; completing it
		// makes the song play from deezer.
		if out.errorType == "" && isrc != "" && deezerCanServeByISRC(isrc) {
			out.errorType = "verification_required"
			out.service = "deezer"
			out.err = fmt.Errorf("deezer tiene la cancion pero requiere verificacion para reproducirla")
		}
		return out
	}
	// A provider handed back an encrypted/DRM file with a key but no CLI ffmpeg
	// to decrypt it here: keep it and let the client decrypt (ffmpeg-kit).
	if res.Encrypted && res.ClientDecrypt && res.DecryptionKey != "" {
		return &streamFallbackOutcome{encrypted: &streamEncryptedInfo{
			FilePath:    res.FilePath,
			Key:         res.DecryptionKey,
			OutputExt:   res.OutputExtension,
			InputFormat: res.InputFormat,
		}}
	}
	// A provider that only has an encrypted/DRM stream (and no usable decrypt
	// path) would leave a file the player cannot decode. Never serve it as a
	// "playable" fallback — that only caused an endless "Error decoding audio"
	// loop on the device.
	if res.Encrypted {
		_ = os.Remove(res.FilePath)
		return &streamFallbackOutcome{err: fmt.Errorf("%s: stream encriptado no reproducible", res.Provider)}
	}
	// The orchestrator already transformed the file to the user's chosen
	// quality (lossy → mp3 bitrate, lossless kept as-is), so no extra step here.
	evictStreamCache(outDir)
	abs, err := filepath.Abs(res.FilePath)
	if err != nil {
		abs = res.FilePath
	}
	return &streamFallbackOutcome{fileURL: "file://" + filepath.ToSlash(abs)}
}

// streamCacheDirPath returns the directory for stream-fallback audio files.
// Lives inside the user's download dir so it follows the chosen storage
// location, mirroring the normal download folder logic.
func streamCacheDirPath() string {
	base := downloadDir
	if base == "" {
		base = download.GlobalOutputDir()
	}
	if base == "" {
		base = os.TempDir()
	}
	return filepath.Join(base, ".stream_cache")
}

// evictStreamCache bounds the stream cache to the configured MB cap (or the
// plan limit when unset) and to a sane file count, deleting the oldest files
// first so repeated fallback downloads don't fill the disk.
func evictStreamCache(dir string) {
	limitMB := streamCacheMaxMB
	if limitMB <= 0 {
		limitMB = streamCacheLevelLimitMB()
	}
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	type f struct {
		path string
		mod  time.Time
		size int64
	}
	var files []f
	var total int64
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		info, err := e.Info()
		if err != nil {
			continue
		}
		files = append(files, f{filepath.Join(dir, e.Name()), info.ModTime(), info.Size()})
		total += info.Size()
	}
	if len(files) == 0 {
		return
	}
	sort.Slice(files, func(i, j int) bool { return files[i].mod.Before(files[j].mod) })
	maxBytes := int64(limitMB) * 1024 * 1024
	const maxFiles = 60
	for i := 0; i < len(files); i++ {
		remaining := len(files) - i
		if remaining <= maxFiles && total <= maxBytes {
			break
		}
		if os.Remove(files[i].path) == nil {
			total -= files[i].size
		}
	}
}

// StreamAudioChunk fetches a byte range of audio directly (mobile/AAR).
func StreamAudioChunk(payload string) string {
	if streamer == nil {
		streamer = streaming.NewStreamer()
	}
	var params struct {
		AudioURL  string `json:"audioURL"`
		OffsetStr string `json:"offset"`
		LengthStr string `json:"length"`
	}
	if err := json.Unmarshal([]byte(payload), &params); err != nil {
		return `{"error":"payload inválido"}`
	}
	offset, _ := strconv.ParseInt(params.OffsetStr, 10, 64)
	length, _ := strconv.ParseInt(params.LengthStr, 10, 64)
	if length <= 0 {
		length = 256 * 1024 // default 256KB chunk
	}
	data, err := streamer.StreamChunk(params.AudioURL, offset, length)
	if err != nil {
		return jsonError(err)
	}
	encoded := base64.StdEncoding.EncodeToString(data)
	result := map[string]interface{}{
		"data":   encoded,
		"size":   len(data),
		"offset": offset,
	}
	out, _ := json.Marshal(result)
	return string(out)
}
