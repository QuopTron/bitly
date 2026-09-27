package provider

// isrc_derive.go — Derivación de ISRC para fuentes que NO lo exponen.
//
// Por qué existe: YouTube, SoundCloud y los re-subidos no publican ISRC. Sin
// ISRC, el camino exacto de reproducción (phase 1 de rescueStream) y el rescate
// FLAC por ISRC (provider/flacrescue) quedan fuera de juego: esos tracks
// terminan servidos con lo que dé el buscador por nombre, que en YouTube es un
// stream lossy de ~128-160 kbps.
//
// Qué hace: cuando la canción no trae ISRC, busca la MISMA canción en los
// catálogos que sí lo publican (Deezer, Qobuz, Tidal, Apple, Spotify) y devuelve
// el ISRC VERIFICADO. Con ese ISRC la cadena puede resolver la fuente exacta y,
// si no hay sesión, el rescate FLAC por ISRC — sin pedirle nada al usuario.
//
// Por qué es seguro: no se acepta cualquier resultado. Solo se devuelve el ISRC
// de un candidato que (a) es el ORIGINAL (título fuerte + artista fuerte, sin
// remix/live/cover respecto de la consulta) y (b) tiene una duración compatible
// con la pedida. Un ISRC equivocado es peor que no tener ISRC: serviría otra
// grabación, así que ante la duda se devuelve "" y todo sigue por nombre.
//
// Costo: acotado. Un presupuesto total, un orden de proveedores que publican
// ISRC y una caché (aciertos 30 min, fallos 5 min) para que repetir una canción
// no vuelva a pagar las búsquedas.
//
// Se conecta con: streaming/rescue_stream.go (lo llama antes de la fase por
// ISRC) y matching_duracion.go (desempate/verificación por duración).
// Parte del flujo: streaming y descarga sin sesión iniciada.

import (
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
)

// proveedoresConISRC son los catálogos que publican ISRC, en orden de
// preferencia: primero los que responden sin sesión (deezer por ISRC público,
// los -web), después los que pueden requerir cuenta, y AL FINAL musicbrainz.
//
// Por qué musicbrainz está y va último: es la única base de ISRC que no depende
// de una cuenta, una sesión firmada ni un gateway comercial — su API pública
// devuelve el ISRC de la grabación y cubre catálogo que los servicios
// comerciales no tienen (sellos independientes, regional, clásica). Su límite
// es de 1 request por segundo, así que se consulta al final: los catálogos
// rápidos responden primero y el presupuesto de la derivación (4s) acota la
// espera. Es lo que hace que un track indie tenga ISRC y pueda entrar al
// rescate FLAC en vez de quedarse con el stream lossy por nombre.
var proveedoresConISRC = []string{
	"deezer",
	// flacdownloader resuelve por HTTP sin sesión y devuelve el ISRC tal como lo
	// publica Qobuz/TIDAL (es el mismo servicio de las claves del canal firmado).
	// Va segundo: cuando el catálogo principal falla o está frío, este contesta.
	"flacdownloader",
	"qobuz-web", "tidal-web", "qobuz", "tidal",
	"apple-music", "spotify-web", "amazon", "musicbrainz",
}

const (
	// Presupuesto total de la derivación: es un extra sobre el camino de play,
	// no puede bloquear la reproducción. Si no contesta a tiempo, "".
	presupuestoDerivarISRC = 4 * time.Second
	// ventanaOrdenISRC es lo que se espera a un catálogo MÁS preferido cuando
	// otro ya devolvió un ISRC verificado: mantiene la preferencia de
	// proveedoresConISRC sin pagar la latencia del recorrido serial.
	ventanaOrdenISRC = 120 * time.Millisecond
	// Un resultado positivo se recuerda 30 min; uno negativo 5 (los catálogos
	// se actualizan, un "no encontrado" de hoy puede existir mañana).
	ttlISRCDerivado      = 30 * time.Minute
	ttlISRCNoEncontrado  = 5 * time.Minute
	maxCacheISRCDerivado = 512
)

type entradaISRC struct {
	isrc    string
	expires time.Time
}

var (
	isrcDerivadoMu    sync.Mutex
	isrcDerivadoCache = map[string]entradaISRC{}
)

// DerivarISRC busca en los catálogos que publican ISRC la MISMA canción que
// [title]/[artist] y devuelve su ISRC verificado, o "" si no se pudo confirmar.
// [durationMS] es la duración pedida (0 = desconocida): con 0 no hay verificación
// por duración, así que solo se acepta un match estricto de título y artista.
func DerivarISRC(reg *Registry, title, artist string, durationMS int) string {
	title = strings.TrimSpace(title)
	artist = strings.TrimSpace(artist)
	if reg == nil || title == "" || artist == "" {
		return ""
	}
	clave := claveISRCDerivado(title, artist, durationMS)

	isrcDerivadoMu.Lock()
	if e, ok := isrcDerivadoCache[clave]; ok && time.Now().Before(e.expires) {
		isrcDerivadoMu.Unlock()
		return e.isrc
	}
	isrcDerivadoMu.Unlock()

	isrc := buscarISRCEnCatalogos(reg, title, artist, durationMS)
	guardarISRCDerivado(clave, isrc)
	return isrc
}

// claveISRCDerivado incluye un CUBO de duración además de título+artista. Sin él
// dos tomas distintas de la misma canción (el original y un remix/directo con el
// mismo título) compartían la entrada de caché y la segunda recibía el ISRC de la
// primera — justo la identidad equivocada que la derivación existe para evitar.
// El cubo (10s) deja compartir entre proveedores que redondean distinto y separa
// tomas que difieren de verdad.
func claveISRCDerivado(title, artist string, durationMS int) string {
	cubo := "0"
	if durationMS > 0 {
		cubo = strconv.Itoa(1 + durationMS/10000)
	}
	return FoldTrack(title) + "|" + FoldTrack(artist) + "|" + cubo
}

// buscarISRCEnCatalogos consulta TODOS los proveedores con ISRC EN PARALELO y
// devuelve el ISRC del primer original verificado, respetando el orden de
// proveedoresConISRC dentro de una ventana corta.
//
// Por qué en paralelo: antes era un recorrido SERIE con presupuesto total de 4s.
// Si el primer catálogo (deezer) tardaba 3s —o fallaba y gastaba su timeout—, el
// presupuesto se agotaba y MusicBrainz —la única base de ISRC sin cuenta, la que
// cubre sellos independientes, regional y clásica— NUNCA llegaba a consultarse.
// El track se quedaba sin ISRC y con él perdía la fase exacta y el rescate FLAC.
// En paralelo cada catálogo paga su PROPIA latencia (una petición por servicio,
// así que no se multiplican los 429) y el presupuesto sigue acotando la espera.
func buscarISRCEnCatalogos(reg *Registry, title, artist string, durationMS int) string {
	query := title + " " + artist
	type respuesta struct {
		indice int
		isrc   string
	}
	ch := make(chan respuesta, len(proveedoresConISRC))
	lanzados := 0
	for i, name := range proveedoresConISRC {
		if cooldown.IsCooled(name) {
			continue
		}
		p := reg.Get(name)
		if p == nil {
			continue
		}
		lanzados++
		// i se captura por copia para poder ordenar por preferencia.
		go func(i int, p Provider) {
			defer func() {
				// Una extensión que paniquea no puede tumbar la reproducción ni
				// dejar el canal sin respuesta.
				if r := recover(); r != nil {
					ch <- respuesta{indice: i}
				}
			}()
			ch <- respuesta{indice: i, isrc: isrcDeProvider(p, title, artist, durationMS, query)}
		}(i, p)
	}
	if lanzados == 0 {
		return ""
	}
	fin := time.Now().Add(presupuestoDerivarISRC)
	var mejor *respuesta
	// recibidas acota la espera al trabajo REALMENTE lanzado: cuando todos los
	// catálogos ya contestaron (aunque sea "no tengo"), no hay por qué esperar el
	// presupuesto entero — el caso negativo (sin ISRC) es común y bloqueaba 4s.
	recibidas := 0
	for mejor == nil && recibidas < lanzados && time.Now().Before(fin) {
		select {
		case r := <-ch:
			recibidas++
			if r.isrc != "" {
				copia := r
				mejor = &copia
			}
		case <-time.After(time.Until(fin)):
		}
	}
	if mejor == nil {
		return ""
	}
	// Ventana de orden: deja ganar a un catálogo más preferido que está por
	// llegar (sin ventana, el azar de la red decidiría la preferencia).
	limite := time.Now().Add(ventanaOrdenISRC)
	if limite.After(fin) {
		limite = fin
	}
	for time.Now().Before(limite) {
		select {
		case r := <-ch:
			if r.isrc != "" && r.indice < mejor.indice {
				copia := r
				mejor = &copia
			}
		case <-time.After(time.Until(limite)):
		}
	}
	return mejor.isrc
}

// isrcDeProvider busca [query] en [p] y devuelve el ISRC verificado del primer
// candidato ORIGINAL con duración compatible, o "".
func isrcDeProvider(p Provider, title, artist string, durationMS int, query string) string {
	results, err := p.SearchTracks(query, 6)
	if err != nil || len(results) == 0 {
		return ""
	}
	// RankOriginalCandidatesDuracion ya deja los originales primero y desempata
	// por duración; solo falta exigir ISRC y re-confirmar que el candidato es
	// estricto (el pass "best-effort" no sirve para derivar un ISRC: sin artista
	// confirmado el ISRC podría ser de otra grabación).
	for _, cand := range RankOriginalCandidatesDuracion(title, artist, durationMS, results) {
		if strings.TrimSpace(cand.ISRC) == "" {
			continue
		}
		if _, ok := OriginalStrength(title, artist, cand); !ok {
			continue
		}
		if !duracionCompatible(durationMS, cand.Duration) {
			continue
		}
		return strings.ToUpper(strings.TrimSpace(cand.ISRC))
	}
	return ""
}

// duracionCompatible aplica la MISMA tolerancia que el verificador de descargas
// (duracionCoincide): ±25% con un mínimo de 20s. Con duración desconocida en
// cualquiera de los dos lados devuelve true (no se puede verificar, no se
// rechaza).
func duracionCompatible(queryMS, got int) bool {
	if queryMS <= 0 || got <= 0 {
		return true
	}
	diff := queryMS - got
	if diff < 0 {
		diff = -diff
	}
	tol := queryMS / 4
	if tol < 20000 {
		tol = 20000
	}
	return diff <= tol
}

func guardarISRCDerivado(clave, isrc string) {
	isrcDerivadoMu.Lock()
	defer isrcDerivadoMu.Unlock()
	if len(isrcDerivadoCache) > maxCacheISRCDerivado {
		isrcDerivadoCache = map[string]entradaISRC{}
	}
	ttl := ttlISRCDerivado
	if isrc == "" {
		ttl = ttlISRCNoEncontrado
	}
	isrcDerivadoCache[clave] = entradaISRC{isrc: isrc, expires: time.Now().Add(ttl)}
}
