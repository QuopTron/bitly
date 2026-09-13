package streaming

import (
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

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
// antes de streamear — el race entonces devuelve ("", proveedor, true)
// INMEDIATAMENTE (el proveedor mas rapido en llegar al challenge gana) para
// que el llamador pueda mostrar el modal de verificacion en ~1-2s en vez de
// recorrer cada proveedor.
func carreraRescue(reg *provider.Registry, names []string, budget time.Duration, workers int, attempt func(name string, p provider.Provider) (string, bool)) (string, string, bool) {
	return carreraRescueConFiltro(reg, names, budget, workers, attempt, nil)
}

// carreraRescueConFiltro es carreraRescue con un filtro de confianza: cuando
// [esReSubido] marca un proveedor y aún quedan fuentes EXACTAS en vuelo, su
// resultado espera [graceExactos] (o a que terminen las exactas) antes de
// ganar. Con [esReSubido] nil el comportamiento es el de siempre.
func carreraRescueConFiltro(reg *provider.Registry, names []string, budget time.Duration, workers int, attempt func(name string, p provider.Provider) (string, bool), esReSubido func(string) bool) (string, string, bool) {
	if len(names) == 0 {
		return "", "", false
	}
	results := make(chan rescueOut, len(names))
	verifyCh := make(chan string, len(names))
	done := make(chan struct{})
	var wg sync.WaitGroup
	sem := make(chan struct{}, workers)
	deadline := time.Now().Add(budget)
	// Fuentes EXACTAS realmente lanzadas: mientras quede al menos una en vuelo,
	// un resultado de re-subido espera (ver graceExactos).
	exactosEnVuelo := 0

	// Spawn workers, but NEVER let the semaphore block the caller: a worker
	// leaked from a previous race (a JS call that never returns holds its
	// sandbox mutex + its sem slot) would otherwise deadlock this spawn loop
	// BEFORE cualquier budget existe — el whole solicitud hangs forever. Each
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
			if esReSubido == nil || !esReSubido(name) {
				exactosEnVuelo++
			}
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

	return recogerResultados(results, verifyCh, done, &deadline, exactosEnVuelo, esReSubido)
}

// carreraPorConfianza es la carrera de rescate consciente de la CONFIANZA de
// cada fuente: todas corren en paralelo (misma latencia que antes), pero un
// resultado de un re-subido (YouTube / YouTube Music / SoundCloud) espera una
// gracia corta a que llegue la grabación EXACTA antes de aceptarse.
//
// Por qué existe: antes ganaba el primero que respondía, que casi siempre era
// YouTube/YouTube Music; una fuente con la grabación exacta (deezer/qobuz/tidal/
// amazon o el rescate por ISRC) llegaba tarde y ya no contaba. Ahora la fuente
// exacta gana si puede, y el re-subido solo sirve cuando ninguna exacta lo hizo
// (una canción sonando es mejor que un fallo de reproducción).
func carreraPorConfianza(reg *provider.Registry, names []string, budget time.Duration, workers int, attempt func(string, provider.Provider) (string, bool)) (string, string, bool) {
	u, prov, v := carreraRescueConFiltro(reg, names, budget, workers, attempt, esProveedorReSubido)
	return u, prov, v
}

// graceExactos es cuánto espera un resultado de re-subido a que llegue una
// fuente exacta. Corto a propósito: si la fuente exacta necesita sesión o su
// espejo está caído, la reproducción no se queda esperando.
const graceExactos = 2500 * time.Millisecond

// verifyGrace is how long a verification signal waits for a real stream to
// land before committing to the "needs session" verdict. A provider that only
