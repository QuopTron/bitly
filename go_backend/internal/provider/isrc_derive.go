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
	"strings"
	"sync"
	"time"
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
	"deezer", "qobuz-web", "tidal-web", "qobuz", "tidal",
	"apple-music", "spotify-web", "amazon", "musicbrainz",
}

const (
	// Presupuesto total de la derivación: es un extra sobre el camino de play,
	// no puede bloquear la reproducción. Si no contesta a tiempo, "".
	presupuestoDerivarISRC = 4 * time.Second
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
	clave := FoldTrack(title) + "|" + FoldTrack(artist)

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

// buscarISRCEnCatalogos recorre los proveedores con ISRC hasta encontrar un
// original verificado. Respeta el presupuesto total.
func buscarISRCEnCatalogos(reg *Registry, title, artist string, durationMS int) string {
	fin := time.Now().Add(presupuestoDerivarISRC)
	query := title + " " + artist
	for _, name := range proveedoresConISRC {
		if time.Now().After(fin) {
			return ""
		}
		p := reg.Get(name)
		if p == nil {
			continue
		}
		results, err := p.SearchTracks(query, 6)
		if err != nil || len(results) == 0 {
			continue
		}
		// RankOriginalCandidatesDuracion ya deja los originales primero y
		// desempata por duración; solo falta exigir ISRC y re-confirmar que el
		// candidato es estricto (el pass "best-effort" no sirve para derivar un
		// ISRC: sin artista confirmado el ISRC podría ser de otra grabación).
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
