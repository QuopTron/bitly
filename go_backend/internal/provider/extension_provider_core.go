package provider

import (
	"github.com/zarz/bitly/go_backend/internal/extensions"
)

type ExtensionProvider struct {
	extID       string
	name        string
	runtime     *extensions.Runtime
	hasHomeFeed bool
	// qOpts mirrors the manifest's qOpts list, so the
	// download/stream fallback can pass a quality token the extension actually
	// recognizes instead of a source-provider token that doesn't map.
	qOpts []string
	// downloadCapable is false for metadata-only extensions (e.g. spotify-web)
	// that expose no download()/getDownloadUrl(), so the fallback can skip them
	// quickly instead of attempting a doomed download for every track.
	downloadCapable bool
	// urlPatterns mirrors the manifest's urlHandler.patterns — los hosts/rutas
	// de enlace que esta extensión sabe resolver con handleUrl(url). Sirve para
	// enrutar un enlace compartido/pegado a la extensión correcta en vez de
	// preguntarle a las nueve.
	urlPatterns []string
	// hasLyrics mirrors the manifest's lyrics_provider type. Declararlo evita
	// ejecutar el JS de la extensión solo para descubrir que NO exporta
	// fetchLyrics: en el arranque eso compilaba las nueve extensiones para
	// descartar ocho, que es justo el costo que se sacó del arranque.
	hasLyrics bool
	// lyricsDeclarado separa "el manifest dijo que no" de "todavía no lo
	// sabemos". Sin esta marca, un manifest que NO lista lyrics_provider
	// (hasLyrics == false) era indistinguible de una extensión cargada desde
	// disco sin manifest, y el wiring caía al sondeo contra la VM — que con el
	// arranque diferido significa compilarla entera.
	lyricsDeclarado bool
}

// NewExtensionProvider creates a new provider backed by a JS extension.
func NewExtensionProvider(extID, name string, rt *extensions.Runtime) *ExtensionProvider {
	return &ExtensionProvider{
		extID:           extID,
		name:            name,
		runtime:         rt,
		downloadCapable: true, // optimistic; SetDownloadCapable(false) on metadata-only
	}
}

// SetHomeFeedEnabled marks whether the extension declares the homeFeed
// capability in its manifest (equivalent to SpotiFLAC's `hasHomeFeed`).
func (p *ExtensionProvider) SetHomeFeedEnabled(v bool) { p.hasHomeFeed = v }

// SetURLPatterns guards the manifest's urlHandler values.
func (p *ExtensionProvider) SetURLPatterns(ps []string) { p.urlPatterns = ps }

// URLPatterns returns the host/subpath patterns this extension claims to
// resolve, or nil when it declares no urlHandler.
func (p *ExtensionProvider) URLPatterns() []string { return p.urlPatterns }

// SetLyricsProvider marks whether the extension declares the lyrics_provider
// capability in its manifest (it exports fetchLyrics). Deja constancia de que el
// manifest YA respondió, para que HasLyricsProvider no tenga que sondear la VM.
func (p *ExtensionProvider) SetLyricsProvider(v bool) {
	p.hasLyrics = v
	p.lyricsDeclarado = true
}

// SetQualityOptions stores the extension's declared quality option IDs.
func (p *ExtensionProvider) SetQualityOptions(qs []string) { p.qOpts = qs }

// QualityOptions returns the extension's declared quality option IDs, or nil.
func (p *ExtensionProvider) QualityOptions() []string { return p.qOpts }

// SetDownloadCapable marks whether the extension can produce audio files.
func (p *ExtensionProvider) SetDownloadCapable(v bool) { p.downloadCapable = v }

// DownloadCapable reports whether the extension can produce audio files.
func (p *ExtensionProvider) DownloadCapable() bool { return p.downloadCapable }

// HomeFeedEnabled reports whether the extension supports a home feed.
func (p *ExtensionProvider) HomeFeedEnabled() bool { return p.hasHomeFeed }

func (p *ExtensionProvider) Name() string { return p.name }

// call invokes a JS method on the extension, honoring the shared per-provider
// circuit breaker (internal/cooldown):
//   - while the provider is cooling down (recent HTTP 429 / rate-limit), calls
//     are skipped fast (nil, nil) instead of re-hitting the API — search,
//     download fallback and prefetch all converge here, so a hammered provider
//     stops being queried everywhere;
//   - a failed call whose error mentions rate-limit / unavailability / blocked
//     puts the provider on cooldown;
//   - a successful response clears the cooldown so a recovered provider is used
//     again immediately.
//
// The 429 errores de extension HTTP helpers (e.g. deezer's getJSON throws// "HTTP 429 for ...") surface through this error path; callers that previously
// swallowed them (return nil, nil) now still trip the breaker, which is what
