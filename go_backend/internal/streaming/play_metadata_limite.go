// ─────────────────────────────────────────────────────────────────────────
// play_metadata_limite.go — Presupuestos y paralelismo de la fase de METADATA
// (identidad: título, artista, ISRC, ids cross-proveedor).
//
// Por qué existe: medido con el arnés real (TestStreamDiagE2E), un track sin
// ISRC tardaba 68,5s de punta a punta con el RESCATE resuelto en 3,5s — o sea,
// el 95% del tiempo era espera de esta fase. La causa: una sola llamada a una
// extensión (búsqueda por nombre en amazon) se quedó 65s, y el recorrido de
// catálogos era SERIAL, así que cada proveedor sumaba su latencia.
//
// Regla de oro acá: la metadata es una MEJORA, nunca un requisito. El audio sale
// del rescate, que corre después con su propia identidad (ISRC/ids del pedido y
// DerivarISRC). Un proveedor lento no puede retener la reproducción: se le da su
// ventana, se lo abandona y el resultado tardío se aprovecha para la caché.
//
// Se conecta con: play_metadata.go (lo usa) + play_metacache.go (caché segura
// para escrituras concurrentes).
// Parte del flujo: reproducción (resolución de identidad antes del stream).
// ─────────────────────────────────────────────────────────────────────────

package streaming

import (
	"log"
	"time"

	"github.com/zarz/bitly/go_backend/internal/cooldown"
	"github.com/zarz/bitly/go_backend/internal/provider"
)

const (
	// presupuestoBloquePreferido acota TODO el bloque del proveedor preferido
	// (la llamada por ISRC, la del id nativo y su búsqueda por nombre). 2s es lo
	// medido para un catálogo que responde bien (apple-music: 1,2s); los que
	// tardan 3-4,4s (spotify-web) se abandonan y su resultado tardío queda en la
	// caché, así el próximo tap es instantáneo. El rescate sigue teniendo la
	// identidad del PEDIDO, no la de esta llamada.
	presupuestoBloquePreferido = 2 * time.Second
	// presupuestoIdentidadConocida es la ventana cuando el PEDIDO ya trae
	// identidad (ISRC o ids cross-proveedor): ahí esta fase solo busca metadata
	// RICA (portada, álbum, duración) y no puede costar segundos de tap. Con los
	// 2s de arriba, un tap de 4,5s gastaba casi la mitad esperando algo
	// prescindible; con 400ms el stream arranca ya y el paquete se completa con
	// el proveedor que ganó el rescate.
	presupuestoIdentidadConocida = 400 * time.Millisecond
	// presupuestoISRCCruzado es el recorrido por ISRC entre los demás proveedores
	// (una llamada exacta cada uno): corre en paralelo, así que es el tope del
	// conjunto, no la suma.
	presupuestoISRCCruzado = 900 * time.Millisecond
	// presupuestoNombreCruzado es la búsqueda por nombre de último recurso entre
	// los demás proveedores: corta a propósito. El rescate hace EXACTAMENTE la
	// misma búsqueda para conseguir el audio, así que esperar acá es duplicar.
	presupuestoNombreCruzado = 1200 * time.Millisecond
	// ventanaOrden deja que un proveedor anterior en la lista (más preferido)
	// alcance a un proveedor posterior que respondió un pelo antes: mantiene la
	// preferencia de orden sin pagar la latencia del recorrido serial.
	ventanaOrden = 120 * time.Millisecond
)

// resolverConPresupuesto ejecuta [fn] y devuelve su resultado solo si llega
// dentro de [d]. Si se agota, devuelve nil y deja la llamada abandonada en
// segundo plano: el resultado tardío no se pierde, porque el llamador le pasa
// una [fn] que ya guarda lo que encuentra en la caché de metadata (así el
// próximo pedido de la misma canción lo aprovecha instantáneamente).
func resolverConPresupuesto(d time.Duration, fn func() *provider.TrackResult) *provider.TrackResult {
	if d <= 0 {
		return fn()
	}
	ch := make(chan *provider.TrackResult, 1)
	go func() {
		defer func() {
			// Una extensión que paniquea no puede tumbar la reproducción.
			if r := recover(); r != nil {
				log.Printf("[play] metadata: pánico en proveedor: %v", r)
				ch <- nil
			}
		}()
		ch <- fn()
	}()
	select {
	case t := <-ch:
		return t
	case <-time.After(d):
		return nil
	}
}

// buscarEnParalelo lanza [fn] sobre cada proveedor de [names] a la vez (excepto
// [excluir]) y devuelve el primer resultado no nil. Respeta [ventanaOrden] para
// no romper la preferencia de orden: si dos respondieron casi juntos, gana el
// que va antes en la lista. Devuelve nil si nadie aporta nada dentro de
// [presupuesto] — el llamador sigue sin metadata, que es un caso válido.
func buscarEnParalelo(
	reg *provider.Registry,
	names []string,
	excluir string,
	presupuesto time.Duration,
	fn func(p provider.Provider, name string) *provider.TrackResult,
) *provider.TrackResult {
	if reg == nil {
		return nil
	}
	type llegada struct {
		indice int
		track  *provider.TrackResult
	}
	ch := make(chan llegada, len(names))
	lanzados := 0
	for i, name := range names {
		if name == excluir || cooldown.IsCooled(name) {
			continue
		}
		p := reg.Get(name)
		if p == nil {
			continue
		}
		lanzados++
		// i se captura por copia para poder ordenar por preferencia.
		go func(i int, name string, p provider.Provider) {
			defer func() {
				if r := recover(); r != nil {
					log.Printf("[play] metadata: pánico en %s: %v", name, r)
					ch <- llegada{indice: i}
				}
			}()
			ch <- llegada{indice: i, track: fn(p, name)}
		}(i, name, p)
	}
	if lanzados == 0 {
		return nil
	}
	fin := time.Now().Add(presupuesto)
	var mejor *llegada
	// Espera del primer resultado con dato hasta agotar el presupuesto.
	for mejor == nil && time.Now().Before(fin) {
		select {
		case l := <-ch:
			if l.track != nil {
				copia := l
				mejor = &copia
			}
		case <-time.After(time.Until(fin)):
		}
	}
	if mejor == nil {
		return nil
	}
	// Ventana corta: si un proveedor más preferido está por llegar, se lo deja
	// ganar (sin ventana, el azar de la red decidiría la preferencia).
	limiteVentana := time.Now().Add(ventanaOrden)
	if limiteVentana.After(fin) {
		limiteVentana = fin
	}
	for time.Now().Before(limiteVentana) {
		select {
		case l := <-ch:
			if l.track != nil && l.indice < mejor.indice {
				copia := l
				mejor = &copia
			}
		case <-time.After(time.Until(limiteVentana)):
		}
	}
	return mejor.track
}
