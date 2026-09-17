package download

import (
	"fmt"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

// candidatosFeeder entrega candidatos verificados BAJO DEMANDA, en el orden del
// try-list, a medida que la carrera le pide más.
//
// Por qué existe: antes la lista se cortaba en maxParallelCandidates (4) ANTES
// de descargar nada. Como el orden arranca por los catálogos exactos
// (amazon/deezer/qobuz) y esos pueden estar sin cuenta o rate-limited, los 4
// puestos se llenaban con fuentes que fallan al instante y las que SÍ pueden
// entregar audio (InnerTube/YouTube, SoundCloud, Internet Archive) nunca
// entraban a la carrera: la descarga terminaba en "fallaron todos" aunque
// hubiera de sobra de dónde bajarla.
//
// El tope ahora es de intentos SIMULTÁNEOS (maxParallelDownloads) y no de
// candidatos totales: apenas una fuente que falla rápido libera su lugar, se
// verifica y entra la siguiente.
type candidatosFeeder struct {
	o        *Orchestrator
	req      Request
	lookKey  string
	st       *fallbackState
	tryOrder []string

	// mu serializa las llamadas a siguiente(): cada candidato puede requerir
	// llamadas de red (resolver el id, verificar que sea la canción correcta) y
	// el estado del iterador se comparte entre los intentos que van pidiendo
	// trabajo en paralelo.
	mu  sync.Mutex
	pos int
}

// nuevoFeeder crea el feeder para un request.
func (o *Orchestrator) nuevoFeeder(
	tryOrder []string,
	req Request,
	lookKey string,
	st *fallbackState,
) *candidatosFeeder {
	return &candidatosFeeder{o: o, req: req, lookKey: lookKey, st: st, tryOrder: tryOrder}
}

// siguiente devuelve el próximo candidato ya resuelto y verificado (que su id
// corresponde a la canción pedida), o false si se agotó el try-list o el
// presupuesto de búsqueda.
func (f *candidatosFeeder) siguiente() (providerAttempt, bool) {
	f.mu.Lock()
	defer f.mu.Unlock()
	o, req, st := f.o, f.req, f.st
	for f.pos < len(f.tryOrder) {
		// El canal RPC de Android corta getStreamPackage a los 60s: al agotar el
		// presupuesto no se inician intentos nuevos (uno ya en curso nunca se
		// interrumpe) para devolver un error estructurado a tiempo.
		if time.Since(st.fallbackStart) > maxFallbackDuration {
			st.lastErr = "fallback: tiempo de búsqueda agotado"
			return providerAttempt{}, false
		}
		name := f.tryOrder[f.pos]
		f.pos++
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
		// Un proveedor que ya avisó que no puede servir audio (catálogo sin
		// cuenta propia, extensión metadata-only) se salta sin gastar
		// resolución: reintentarlo no cambia nada y quema el presupuesto que
		// necesitan las fuentes que sí entregan archivos.
		if providerSinAudio(name) {
			continue
		}
		// Circuit breaker: skip providers cooling down from rate-limits (429).
		if cooldown.IsCooledOp(name, downloadCooldownOp) {
			continue
		}
		trackID, title, artist := resolucionCacheada(p, name, f.lookKey, req)
		if trackID == "" {
			continue
		}
		// Un proveedor que no es el dueño del track resuelve el id por cruce de
		// ids, ISRC o búsqueda: nunca se descarga una canción parecida. Se
		// verifica contra el registro del propio proveedor; el id nativo del
		// dueño se confía (ES la canción fuente).
		if name != req.Provider && req.Title != "" {
			if !confirmarMatchDescarga(p, trackID, req.ISRC, req.Title, req.Artist, req.DurationMS) {
				st.lastErr = fmt.Sprintf("%s: el stream no es la cancion solicitada", name)
				continue
			}
		}
		return providerAttempt{name, p, trackID, title, artist}, true
	}
	return providerAttempt{}, false
}
