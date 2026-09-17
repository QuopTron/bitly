// ─────────────────────────────────────────────────────────────
// capa.go — Caché con vencimiento y "un solo vuelo" del cliente de
// Last.fm.
//
// Por qué: el sitio castiga las ráfagas, así que la misma página no se
// pide dos veces (caché) y nunca se pide dos veces EN PARALELO (vuelo).
// Sin esto, abrir un álbum con 17 pistas podía disparar varias
// peticiones iguales.
// ─────────────────────────────────────────────────────────────

package lastfm

import (
	"sync"
	"time"
)

// cachePaginas guarda HTML por ruta con vencimiento y tamaño acotado.
type cachePaginas struct {
	mu       sync.Mutex
	entradas map[string]entradaPagina
	max      int
}

type entradaPagina struct {
	cuerpo string
	expira time.Time
}

// vencimientos: una ficha cambia muy poco, así que la caché es larga. Es lo
// que permite que un álbum completo cueste UNA petición y no una por pista.
const (
	vencPagina = 12 * time.Hour
)

func newCachePaginas(max int) *cachePaginas {
	return &cachePaginas{entradas: make(map[string]entradaPagina), max: max}
}

func (c *cachePaginas) leer(clave string) (string, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	e, ok := c.entradas[clave]
	if !ok {
		return "", false
	}
	if time.Now().After(e.expira) {
		delete(c.entradas, clave)
		return "", false
	}
	return e.cuerpo, true
}

func (c *cachePaginas) guardar(clave, cuerpo string) {
	c.mu.Lock()
	defer c.mu.Unlock()
	// Poda simple: si se pasó del tope se descarta lo que ya venció y, si
	// sigue lleno, una entrada cualquiera (el mapa no guarda orden y no hace
	// falta: la caché es un atajo, no una fuente de verdad).
	if len(c.entradas) >= c.max {
		ahora := time.Now()
		for k, e := range c.entradas {
			if ahora.After(e.expira) {
				delete(c.entradas, k)
			}
		}
		for k := range c.entradas {
			if len(c.entradas) < c.max {
				break
			}
			delete(c.entradas, k)
		}
	}
	c.entradas[clave] = entradaPagina{cuerpo: cuerpo, expira: time.Now().Add(vencPagina)}
}

// vuelos agrupa peticiones simultáneas de la MISMA ruta: la primera baja la
// página y las demás esperan ese resultado en vez de gastar otra petición.
type vuelos struct {
	mu       sync.Mutex
	abiertos map[string]chan struct{}
}

func newVuelos() *vuelos {
	return &vuelos{abiertos: make(map[string]chan struct{})}
}

// entrar reserva la ruta. Devuelve primero=true cuando este llamador es el que
// baja la página (y entonces DEBE llamar a listo() al terminar).
func (v *vuelos) entrar(clave string) (primero bool, listo func()) {
	v.mu.Lock()
	if ch, ok := v.abiertos[clave]; ok {
		v.mu.Unlock()
		return false, func() { _ = ch }
	}
	ch := make(chan struct{})
	v.abiertos[clave] = ch
	v.mu.Unlock()
	return true, func() {
		v.mu.Lock()
		delete(v.abiertos, clave)
		v.mu.Unlock()
		close(ch)
	}
}

// esperarHastaListo bloquea hasta que el vuelo en curso termine.
func (v *vuelos) esperarHastaListo(clave string) {
	v.mu.Lock()
	ch, ok := v.abiertos[clave]
	v.mu.Unlock()
	if !ok {
		return
	}
	<-ch
}
