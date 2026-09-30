// ─────────────────────────────────────────────────────────────
// stream_url_memo.go — Caché + single-flight de GetStreamURL.
//
// El mismo par proveedor+identidad+calidad se resolvía más de una vez en un
// mismo pedido (la fase de identidades y las fases del rescate vuelven a
// probar el proveedor que ya contestó) y otra vez en cada re-toco: cada
// vuelta es una ida a la red del proveedor —una extensión firma su sesión,
// un catálogo consulta su API— y a veces un TLS handshake completo.
//
// Dos controles, cada uno con su porqué:
//
//   · SINGLE-FLIGHT: dos resoluciones idénticas EN VUELO comparten una sola
//     llamada. No retiene nada entre pedidos, así que no puede entregar una
//     respuesta vieja: lo que comparte es la que está corriendo ahora.
//
//   · CACHÉ DEL ÉXITO, corta: una URL ya resuelta sirve por
//     [vidaMemoStreamURL]. Solo se memoriza cuando hubo URL y no hubo error:
//     los ERRORES no se guardan a propósito, porque el reintento del cliente
//     (un tap que vuelve a pedir el mismo track 400 ms después cuando la
//     sesión estaba fría) tiene que llegar al proveedor de verdad —memorizar
//     el error convertiría ese reintento en un eco del primer fallo.
//
// Se conecta con: play_quick.go (atajo), rescue_try/rescue_probe/
// rescue_lossless (fases del rescate) y gobackend/stream_rpc.go (la RPC
// getStreamURL). Parte del flujo: reproducción (resolución de stream).
// ─────────────────────────────────────────────────────────────

package streaming

import (
	"fmt"
	"sync"
	"sync/atomic"
	"time"

	"github.com/zarz/bitly/go_backend/internal/provider"
)

// memoURLActiva apaga la caché para los tests del paquete (ver main_test.go):
// una entrada guardada por un test le robaría llamadas —y por tanto afirmaciones
// de conteo— a otro. En producción arranca encendida.
var memoURLActiva atomic.Bool

func init() { memoURLActiva.Store(true) }

// MemoStreamURL activa o apaga esta caché. Lo usan las pruebas que MIDE la
// reproducción (tap_diag / streaming_e2E, en gobackend): miden lo que corre el
// usuario, así que la vuelven a encender mientras miden.
func MemoStreamURL(activa bool) { memoURLActiva.Store(activa) }

// vidaMemoStreamURL es cuánto se sirve una URL ya resuelta. Corta a propósito:
// alcanza para que un re-toco, el prefetch del vecino de cola o la otra fase
// del rescate reutilicen el resultado, y queda muy por debajo de la vida
// mínima de una URL firmada (minutos) para que nadie reciba un enlace vencido.
const vidaMemoStreamURL = 30 * time.Second

type memoURLEntrada struct {
	url   string
	hasta time.Time
}

// vueloStreamURL es una resolución idéntica que todavía corre: los que llegan
// después esperan su resultado en vez de abrir otra.
type vueloStreamURL struct {
	done chan struct{}
	url  string
	err  error
}

var (
	memoURLMu   sync.Mutex
	memoURLs    = map[string]memoURLEntrada{}
	vuelosURLMu sync.Mutex
	vuelosURL   = map[string]*vueloStreamURL{}
)

func claveMemoURL(proveedor, id, calidad string) string {
	return proveedor + "|" + id + "|" + calidad
}

// memoURLLeer devuelve la URL memorizada para [clave], si todavía vive.
func memoURLLeer(clave string) (string, bool) {
	memoURLMu.Lock()
	defer memoURLMu.Unlock()
	e, ok := memoURLs[clave]
	if !ok {
		return "", false
	}
	if time.Now().After(e.hasta) {
		delete(memoURLs, clave)
		return "", false
	}
	return e.url, true
}

// memoURLGuardar anota el ÉXITO de una resolución. Los errores no pasan por
// acá (ver cabecera): cada llamador sigue viendo el error real del proveedor.
func memoURLGuardar(clave, url string) {
	memoURLMu.Lock()
	defer memoURLMu.Unlock()
	if len(memoURLs) > 512 {
		ahora := time.Now()
		for k, v := range memoURLs {
			if ahora.After(v.hasta) {
				delete(memoURLs, k)
			}
		}
	}
	memoURLs[clave] = memoURLEntrada{url: url, hasta: time.Now().Add(vidaMemoStreamURL)}
}

// olvidarStreamURL descarta la entrada memorizada de [proveedor, id, calidad].
// Para cuando el llamador rechaza la URL que le devolvió (un clip de muestra,
// por ejemplo): el próximo pedido tiene que volver a preguntar al proveedor.
func olvidarStreamURL(proveedor, id, calidad string) {
	memoURLMu.Lock()
	defer memoURLMu.Unlock()
	delete(memoURLs, claveMemoURL(proveedor, id, calidad))
}

// PedirStreamURL pide la URL de stream a [p] con caché y single-flight.
// Es la única puerta de entrada a GetStreamURL del lado del streaming: un
// llamador que llegue acá dos veces con la misma identidad paga la red UNA vez.
func PedirStreamURL(p provider.Provider, id, calidad string) (string, error) {
	if p == nil {
		return "", fmt.Errorf("proveedor no disponible")
	}
	if id == "" {
		return "", fmt.Errorf("sin identidad de track")
	}
	// Apagada (tests): la petición va directo al proveedor, sin caché ni vuelo.
	if !memoURLActiva.Load() {
		return p.GetStreamURL(id, calidad)
	}
	clave := claveMemoURL(p.Name(), id, calidad)
	if url, ok := memoURLLeer(clave); ok {
		return url, nil
	}

	// Single-flight: si alguien ya está pidiendo exactamente esto, se espera su
	// resultado en vez de duplicar la llamada. El mapa se toma SOLO para
	// decidir quién corre, nunca durante la petición (que puede tardar
	// segundos): así un proveedor lento no retiene a los demás.
	vuelosURLMu.Lock()
	if v, existe := vuelosURL[clave]; existe {
		vuelosURLMu.Unlock()
		<-v.done
		return v.url, v.err
	}
	v := &vueloStreamURL{done: make(chan struct{})}
	vuelosURL[clave] = v
	vuelosURLMu.Unlock()

	url, err := p.GetStreamURL(id, calidad)
	if err == nil && url != "" {
		memoURLGuardar(clave, url)
	}

	vuelosURLMu.Lock()
	v.url, v.err = url, err
	delete(vuelosURL, clave)
	vuelosURLMu.Unlock()
	close(v.done)
	return url, err
}

// limpiarMemoStreamURL vacía la caché de URLs. Es para los tests: la caché
// sobrevive entre pruebas y una entrada vieja haría que un test contara menos
// llamadas de las que esperaba.
func limpiarMemoStreamURL() {
	memoURLMu.Lock()
	memoURLs = map[string]memoURLEntrada{}
	memoURLMu.Unlock()
}
