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

	// fallosPorProveedor guarda el motivo de cada candidata que falló, en el
	// orden en que se intentaron. Sirve para el log de diagnóstico y para que el
	// mensaje final diga en QUÉ falló cada fuente, no solo que "fallaron todas".
	fallosPorProveedor []string
}

// registrarFallo anota el motivo de una candidata fallida.
func (st *fallbackState) registrarFallo(provider, err string) {
	if strings.TrimSpace(err) == "" {
		return
	}
	if provider == "" {
		provider = "?"
	}
	st.fallosPorProveedor = append(st.fallosPorProveedor, provider+": "+err)
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

	// Restos de intentos anteriores (temporales de la descarga por tramos,
	// copias de etiquetado interrumpidas) no deben quedarse en la carpeta del
	// usuario: los compañeros de esta misma carrera siguen corriendo aunque el
	// primero ya haya ganado y, si el proceso muere, su temporal nunca se
	// borra. Se limpia como mucho una vez cada diez minutos por carpeta y
	// nunca sobre archivos recién escritos (podrían estar en vuelo).
	limpiarRestosSiCorresponde(outDir)

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

	// La carrera pide candidatos AL FEEDER a medida que libera lugares en vez de
	// recibir una lista cortada de antemano: los catálogos sin cuenta fallan al
	// instante y en su lugar entran las fuentes que sí pueden entregar audio
	// (InnerTube/YouTube, SoundCloud, Internet Archive) dentro del presupuesto.
	feeder := o.nuevoFeeder(tryOrder, req, lookKey, st)
	if res := o.consumeCandidates(feeder, req, outDir, st); res != nil {
		// Etiquetas + carátula DENTRO del archivo, best-effort: el usuario
		// descargó una canción completa, no un stream suelto.
		o.etiquetarDescarga(res, req)
		// Mejora silenciosa a sin pérdida: la canción YA está entregada (con
		// pérdida si el ganador fue InnerTube/SoundCloud) y el FLAC se busca
		// después, en segundo plano. No retrasa esta descarga ni la cola.
		o.solicitarMejoraFLAC(req, outDir, res)
		return res
	}

	// ÚLTIMO recurso, invisible: Last.fm publica el video OFICIAL de YouTube de
	// cada pista (el del propio canal del artista). Si todas las fuentes
	// fallaron, se pide el audio por ESE id, sin búsqueda por nombre — que es
	// justo lo que suele fallar. Cacheado, y con el sitio en pausa si devolvió
	// su desafío anti-bot.
	if res := o.intentarConVideoOficial(req, outDir, st); res != nil {
		o.etiquetarDescarga(res, req)
		o.solicitarMejoraFLAC(req, outDir, res)
		return res
	}

	// El motivo REAL (no "all providers failed") va al tracker y al log: es lo
	// único que ve el usuario en el aviso de descarga y lo único que permite
	// diagnosticar sin volver a reproducir el fallo. Antes el tracker recibía
	// siempre el texto genérico y los errores de cada proveedor se perdían en
	// st.lastErr sin registrarse en ningún lado.
	final := st.finalResult(req.ItemID)
	o.tracker.SetError(req.ItemID, final.Error)
	log.Printf(
		"[orchestrator] ✖ FAILED itemID=%q provider=%q type=%q err=%q",
		req.ItemID, final.Provider, final.ErrorType, final.Error,
	)
	return final
}
