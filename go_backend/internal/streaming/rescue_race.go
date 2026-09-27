package streaming

import (
	"sync"
	"sync/atomic"
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
	// Capacidad 2×: un worker puede mandar DOS mensajes (su url y su acuse de
	// bloqueante). Con capacidad N, el que no cabía se quedaba BLOQUEADO en el
	// send sosteniendo su turno del pool — y ese turno nunca volvía, que es
	// justamente el "worker colgado" que el spawn loop de abajo intenta esquivar.
	results := make(chan rescueOut, 2*len(names))
	verifyCh := make(chan string, len(names))
	var wg sync.WaitGroup
	sem := make(chan struct{}, workers)
	deadline := time.Now().Add(budget)
	// [carreraViva] se cierra al volver de recogerResultados (la carrera ya tiene
	// su ganador o se le acabó el presupuesto): los intentos ENCOLADOS que todavía
	// no consiguieron turno se rinden ahí mismo en vez de arrancar una búsqueda
	// cuando la fase ya terminó.
	carreraViva := make(chan struct{})
	defer close(carreraViva)
	// BLOQUEANTES que van a intentarlo (en vuelo o en cola) y TODAVÍA no
	// acusaron. Mientras quede al menos uno, un resultado retenido espera (ver
	// politicaCarrera). Cada bloqueante manda su acuse (rescueOut.finBloqueante)
	// y el contador baja: sin eso, un re-subido (yt-dlp) esperaba la gracia
	// COMPLETA —hasta 6s con calidad sin pérdida— aunque Soulseek, Internet
	// Archive y los catálogos ya hubieran contestado "no tengo nada" en medio
	// segundo. Es atómico porque ahora hay bloqueantes que arrancan DESPUÉS de
	// que el colector ya está leyendo (los encolados).
	var bloqueantes int32

	// reportar es el cuerpo de un worker: intenta, manda su resultado y —si es
	// bloqueante— su acuse. El acuse va SIEMPRE al final y por el mismo canal que
	// el resultado: así el colector lo lee después de la url (si la hubo) y nunca
	// se puede "liberar" un retenido un instante antes de que llegue un
	// bloqueante que sí encontró stream.
	reportar := func(name string, p provider.Provider, esBloqueante bool) {
		if esBloqueante {
			defer func() { results <- rescueOut{finBloqueante: true} }()
		}
		url, verified := attempt(name, p)
		if verified {
			verifyCh <- name
		} else if url != "" {
			results <- rescueOut{name: name, url: url}
		}
	}

	// Spawn workers, but NEVER let the semaphore block the caller: a worker
	// leaked from a previous race (a JS call that never returns holds its
	// sandbox mutex + its sem slot) would otherwise deadlock this spawn loop
	// BEFORE cualquier budget existe — el whole solicitud hangs forever.
	//
	// Por eso ya no se ESPERA un turno acá: si hay uno libre se lo toma (así los
	// primeros de la lista conservan la prioridad), y si no, el intento queda
	// ENCOLADO en su goroutine y reclama el primer turno que se libere dentro del
	// presupuesto. Antes, sin turno en 1s, la fuente se DESCARTABA: con dos turnos
	// ocupados por búsquedas lentas, internetarchive/flac-rescue/soundcloud nunca
	// llegaban a intentarlo. Además el spawn loop ya no retrasa al colector (que
	// arrancaba recién después de recorrer toda la lista).
	for _, name := range names {
		name := name
		p := reg.Get(name)
		if p == nil {
			continue
		}
		if cooldown.IsCooled(name) {
			continue
		}
		esBloqueante := pol.bloquea(name)
		if esBloqueante {
			atomic.AddInt32(&bloqueantes, 1)
		}
		wg.Add(1)
		select {
		case sem <- struct{}{}:
			go func() {
				defer wg.Done()
				defer func() { <-sem }()
				reportar(name, p, esBloqueante)
			}()
		default:
			go func() {
				defer wg.Done()
				if !reclamarTurno(sem, deadline, carreraViva) {
					// No hubo turno dentro del presupuesto: si era bloqueante, avisa
					// que YA no está en vuelo (si no, un retenido esperaría por él
					// la gracia entera sin motivo).
					if esBloqueante {
						results <- rescueOut{finBloqueante: true}
					}
					return
				}
				defer func() { <-sem }()
				reportar(name, p, esBloqueante)
			}()
		}
	}
	// El canal de resultados se CIERRA cuando termina el último worker, en vez
	// de señalarlo con un `done` aparte: Go entrega todo lo que quedó en el
	// buffer ANTES de reportar el cierre, así que el colector nunca puede
	// enterarse de "ya terminaron" dejando un stream sin leer. Con el `done`
	// separado, `select` elegía al azar entre los dos casos listos y podía
	// devolver vacío teniendo una URL válida en el buffer (el "no encontró
	// stream" intermitente, que aparecía justo bajo carga).
	go func() { wg.Wait(); close(results) }()

	return recogerResultados(results, verifyCh, &deadline, &bloqueantes, pol)
}

// esperaTurnoMax es el tope de la espera por un turno del pool. Más corto que
// los presupuestos de las fases a propósito: el caso NORMAL es que un turno se
// libere apenas un proveedor falla (youtube responde su "no tengo ISRC" en
// milisegundos), así que una cola corta alcanza para que la fuente que sigue
// entre — que era justamente la que antes se descartaba. Esperar el presupuesto
// entero por un turno estiraría el camino de FALLO (todos los proveedores
// encolados en serie) sin mejorar la cobertura real.
const esperaTurnoMax = 2500 * time.Millisecond

// reclamarTurno espera un turno libre del pool hasta [deadline] (con el tope
// [esperaTurnoMax]) o hasta que la carrera termine ([carreraViva] cerrada).
// Devuelve false si no lo consiguió (el intento se abandona sin tocar la red).
func reclamarTurno(sem chan struct{}, deadline time.Time, carreraViva <-chan struct{}) bool {
	restante := time.Until(deadline)
	if restante <= 0 {
		return false
	}
	if restante > esperaTurnoMax {
		restante = esperaTurnoMax
	}
	t := time.NewTimer(restante)
	defer t.Stop()
	select {
	case sem <- struct{}{}:
		return true
	case <-t.C:
		return false
	case <-carreraViva:
		return false
	}
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
//
// Bajado de 2,5s a 1,2s: el tope de arranque es "stream en menos de 4s". La
// gracia es un extra OPCIONAL —cuando la fuente exacta ya tiene el id resuelto
// responde en ~1s, y si no apareció en este margen es porque necesita sesión o
// está caída—, así que retener más solo se siente como que el tap no respondió.
const graceExactos = 1200 * time.Millisecond

// graceLossless es la espera cuando la calidad pedida es SIN PÉRDIDA. Bajada de
// 6s a 1,8s por el mismo motivo que graceExactos: 6 segundos de silencio
// esperando un FLAC que podía no llegar hacían que un tap pareciera roto (el
// usuario medía ~16s de punta a punta). Ahora el FLAC solo gana si llega casi
// junto con las demás: un 320k sonando ya es mejor que un FLAC hipotético.
const graceLossless = 1800 * time.Millisecond

// verifyGrace is how long a verification signal waits for a real stream to
// land before committing to the "needs session" verdict. A provider that only
