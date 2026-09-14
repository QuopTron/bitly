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
//
// [finBloqueante] no es un resultado sino el ACUSE de que un proveedor
// bloqueante terminó su intento sin aportar stream. Existe para que un
// resultado retenido no siga esperando a fuentes que YA dijeron que no tienen
// nada: ver la nota de bloqueantesEnVuelo en carreraRescueConFiltro.
type rescueOut struct {
	name          string
	url           string
	finBloqueante bool
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
	return carreraRescueConFiltro(reg, names, budget, workers, attempt, politicaCarrera{})
}

// politicaCarrera decide con cuánta CONFIANZA se acepta un resultado de la
// carrera, sin quitarle a nadie su turno: todos los proveedores siguen
// buscando EN PARALELO, lo único que cambia es a quién se le retiene el
// resultado para esperar a uno mejor.
//
//   - retenido:   su resultado no gana de inmediato; espera una gracia.
//   - bloqueante: mientras alguno de estos siga en vuelo, lo retenido espera.
//   - mejor:      entre dos retenidos, si [mejor] prefiere al nuevo, reemplaza
//     al que estaba esperando (una fuente sin pérdida no debe
//     quedar descartada porque un re-subido lossy respondió antes).
//   - gracia:     cuánto espera un retenido (corta si no, más larga cuando la
//     calidad pedida es sin pérdida).
//
// Con los tres campos en nil el comportamiento es el histórico: gana el
// primero que responda.
type politicaCarrera struct {
	retenido   func(string) bool
	bloqueante func(string) bool
	mejor      func(a, b string) bool
	gracia     time.Duration
}

func (p politicaCarrera) activa() bool {
	return p.retenido != nil && p.bloqueante != nil
}

func (p politicaCarrera) retiene(name string) bool {
	return p.activa() && p.retenido(name)
}

func (p politicaCarrera) bloquea(name string) bool {
	return p.activa() && p.bloqueante(name)
}

// prefiere reporta si [a] es mejor candidato retenido que [b].
func (p politicaCarrera) prefiere(a, b string) bool {
	if p.mejor == nil {
		return false
	}
	return p.mejor(a, b)
}

// graciaEfectiva es la espera de un resultado retenido.
func (p politicaCarrera) graciaEfectiva() time.Duration {
	if p.gracia <= 0 {
		return graceExactos
	}
	return p.gracia
}

// carreraRescueConFiltro es carreraRescue con una [pol] de confianza: cuando
// un proveedor queda RETENIDO y aún quedan BLOQUEANTES en vuelo, su resultado
// espera la gracia antes de ganar. Con una política vacía el comportamiento es
// el de siempre (gana el primero que responde).
func carreraRescueConFiltro(reg *provider.Registry, names []string, budget time.Duration, workers int, attempt func(name string, p provider.Provider) (string, bool), pol politicaCarrera) (string, string, bool) {
	if len(names) == 0 {
		return "", "", false
	}
	results := make(chan rescueOut, len(names))
	verifyCh := make(chan string, len(names))
	done := make(chan struct{})
	var wg sync.WaitGroup
	sem := make(chan struct{}, workers)
	deadline := time.Now().Add(budget)
	// BLOQUEANTES realmente lanzados y TODAVÍA EN VUELO: mientras quede al menos
	// uno, un resultado retenido espera (ver politicaCarrera). Cada bloqueante
	// que termina manda su acuse (rescueOut.finBloqueante) y el contador baja:
	// sin eso, un re-subido (yt-dlp) esperaba la gracia COMPLETA —hasta 6s con
	// calidad sin pérdida— aunque Soulseek, Internet Archive y los catálogos ya
	// hubieran contestado "no tengo nada" en medio segundo. Ver el acuse en
	// recogerResultados.
	bloqueantesEnVuelo := 0

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
		esBloqueante := pol.bloquea(name)
		select {
		case sem <- struct{}{}:
			if esBloqueante {
				bloqueantesEnVuelo++
			}
			wg.Add(1)
			go func() {
				defer wg.Done()
				defer func() { <-sem }()
				url, verified := attempt(name, p)
				if verified {
					verifyCh <- name
				} else if url != "" {
					results <- rescueOut{name: name, url: url}
				}
				// El acuse va SIEMPRE al final y por el mismo canal que el
				// resultado: así el colector lo lee después de la url (si la
				// hubo) y nunca se puede "liberar" un retenido un instante
				// antes de que llegue un bloqueante que sí encontró stream.
				if esBloqueante {
					results <- rescueOut{finBloqueante: true}
				}
			}()
		case <-time.After(wait):
			// No slot freed in time — skip this provider; anything already
			// running may still report via drainResults.
		}
	}
	go func() { wg.Wait(); close(done) }()

	return recogerResultados(results, verifyCh, done, &deadline, bloqueantesEnVuelo, pol)
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
	return carreraPorConfianzaCalidad(reg, names, budget, workers, attempt, "")
}

// carreraPorConfianzaCalidad es carreraPorConfianza sabiendo además la CALIDAD
// pedida: con calidad sin pérdida, una fuente que solo entrega lossy (yt-dlp,
// SoundCloud — que sigue siendo el FALLBACK) espera más a que llegue una que sí
// puede dar FLAC (Internet Archive, Soulseek, flac-rescue), y si llega con buen
// match, suena la de FLAC.
func carreraPorConfianzaCalidad(reg *provider.Registry, names []string, budget time.Duration, workers int, attempt func(string, provider.Provider) (string, bool), quality string) (string, string, bool) {
	return carreraRescueConFiltro(reg, names, budget, workers, attempt, politicaConfianza(quality))
}

// politicaConfianza arma la política de la carrera de rescate: identidad
// EXACTA por encima del re-subido y, cuando la calidad pedida es sin pérdida,
// audio sin pérdida por encima de un transcodificado.
func politicaConfianza(quality string) politicaCarrera {
	lossless := calidadPideLossless(quality)
	gracia := graceExactos
	if lossless {
		gracia = graceLossless
	}
	return politicaCarrera{
		retenido: func(name string) bool {
			// Los que identifican por nombre nunca ganan de un tirón.
			if esProveedorReSubido(name) {
				return true
			}
			// Con calidad sin pérdida pedida, una fuente que no puede entregarla
			// no arranca ganando: es el fallback, no el preferido.
			return lossless && !esProveedorLossless(name)
		},
		bloqueante: func(name string) bool {
			// Una fuente exacta siempre hace esperar a un re-subido.
			if !esProveedorReSubido(name) {
				return true
			}
			// Internet Archive y Soulseek identifican por nombre, pero su audio
			// es lossless de verdad (y sin sesión): con calidad sin pérdida
			// pedida cuentan como bloqueantes, así un FLAC real gana al
			// re-subido que respondió primero.
			return lossless && esFuenteLosslessSiempre(name)
		},
		mejor: func(a, b string) bool {
			if lossless {
				la, lb := esProveedorLossless(a), esProveedorLossless(b)
				if la != lb {
					return la
				}
			}
			ra, rb := esProveedorReSubido(a), esProveedorReSubido(b)
			if ra != rb {
				return rb // entre iguales en calidad, gana la grabación EXACTA
			}
			return false
		},
		gracia: gracia,
	}
}

// graceExactos es cuánto espera un resultado de re-subido a que llegue una
// fuente exacta. Corto a propósito: si la fuente exacta necesita sesión o su
// espejo está caído, la reproducción no se queda esperando.
const graceExactos = 2500 * time.Millisecond

// graceLossless es la espera cuando la calidad pedida es SIN PÉRDIDA: más larga
// que graceExactos porque la fuente que puede darla tarda más (Internet Archive
// resuelve en 1-2s; Soulseek, por la naturaleza de la red, algo más) y porque lo
// que está en juego es 320kbps contra FLAC real. Sigue acotada: la reproducción
// nunca espera más que esto por un "quizá".
const graceLossless = 6 * time.Second

// verifyGrace is how long a verification signal waits for a real stream to
// land before committing to the "needs session" verdict. A provider that only
