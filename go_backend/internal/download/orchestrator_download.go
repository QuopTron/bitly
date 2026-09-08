package download

import (
	"log"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// providerAttempt es un candidato ya resuelto: el provider + el track id que
// resolvió para el ítem (junto con título/artista).
type providerAttempt struct {
	name                   string
	p                      provider.Provider
	trackID, title, artist string
}

// fallbackState acumula el estado del fallback de UNA descarga (variables
// locales del Download original). Es local a cada llamada: nunca se comparte
// entre descargas concurrentes.
type fallbackState struct {
	fallbackStart       time.Time
	lastErr             string
	encryptedSeen       bool
	verificationSeen    bool
	verificationService string
}

// Download executes a single download with provider fallback.
// It acquires a concurrency slot so bursts of batch downloads don't
// saturate the device's CPU, network or disk.
func (o *Orchestrator) Download(req Request) *Result {
	log.Printf("[orchestrator] Download itemID=%q trackID=%q isrc=%q title=%q provider=%q", req.ItemID, req.TrackID, req.ISRC, req.Title, req.Provider)
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

	st := &fallbackState{fallbackStart: time.Now()}

	// Enrich the request's ISRC when the feed item didn't carry one (e.g.
	// tidal/apple/qobuz feeds, or tracks with isrc=null). We try the source
	// provider's own track first, then each cross-provider id via spotify (its
	// metadata carries ISRC reliably), so a track reached from ANY feed gets a
	// strict ISRC. Providers like amazon resolve via SongLink using the ISRC, so
	// el mismo exact source puede ser served en su lugar de falling back a un lossy
	// same-title remix on soundcloud/ytmusic.
	o.enrichISRC(&req)

	// Resolve the track's identity ONCE and share it across every provider: the
	// key is the same (ISRC / identifiers / title+artist) for all of them, so a
	// slow name search (amazon showSearch, etc.) done for one provider never has
	// to be repeated for the others.
	lookKey := req.ISRC
	if lookKey == "" {
		var nonEmpty []string
		for _, id := range []string{req.SpotifyID, req.DeezerID, req.TidalID, req.QobuzID} {
			if id != "" {
				nonEmpty = append(nonEmpty, id)
			}
		}
		lookKey = strings.Join(nonEmpty, "|")
	}
	if lookKey == "" && req.Title != "" {
		lookKey = strings.ToLower(req.Title + "|" + req.Artist)
	}

	// Resolve every candidate provider's track ID in parallel so the fallback
	// loop below never stalls serially on a single provider's slow web search
	// (amazon showSearch etc.). While the preferred provider is still resolving
	// we hand off to whichever provider finished first, so the first play of a
	// brand-new track starts immediately on slow sources.
	tryOrder := o.warmResolveAndOrder(providersToTry, req, lookKey)

	// Construye el candidate lista: cada proveedor que resuelto un canción id para
	// Este item. este fase solo resolves + reverse-verifies (sin network
	// download) and is bounded so we never spend the whole budget enumerating.
	candidates := o.buildCandidates(tryOrder, req, lookKey, st)

	// Fire every candidate's download in parallel ("second plans" delegated to
	// goroutines). The first source to yield a playable, verified file wins;
	// el remaining companions mantener running pero su resultados son discarded y
	// their partial ".tmp." files are never served (StreamCacheFile skips them).
	// This convierte el previamente serial 50s budget en un race where the
	// fastest working source starts producing the file immediately.
	if len(candidates) > 0 {
		if res := o.consumeCandidates(candidates, req, outDir, st); res != nil {
			return res
		}
	}

	o.tracker.SetError(req.ItemID, "all providers failed")
	return st.finalResult(req.ItemID)
}
