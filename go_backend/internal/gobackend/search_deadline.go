package gobackend

import "time"

// ─────────────────────────────────────────────────────────────────────────
// TECHO DE TIEMPO POR PROVEEDOR
//
// Antes, una búsqueda solo tenía UN límite: el global (searchGlobalTimeout,
// 4 s) y únicamente en los caminos "todas las fuentes". La búsqueda de una
// fuente concreta (`?source=...`) no tenía NINGÚN techo, así que un proveedor
// colgado mandaba a la UI a esperar indefinidamente.
//
// Medido contra el backend real, eso no era teórico:
//
//   - `spotify` con credenciales vacías entraba en recursión infinita por el
//     401 (ver provider/spotify/client.go) → 40 s sin responder.
//   - `amazon` recorre 5 storefronts con 2 HTTPS secuenciales cada uno y
//     reinicializaba la sesión por storefront → 40 s sin responder.
//
// Y en los fan-outs el proveedor lento no solo tardaba: consumía la ventana
// global completa, así que la búsqueda "Todas" clavaba 4 s SIEMPRE (los
// resultados rápidos llegaban, pero el sondeo de Flutter no veía `done` hasta
// que expiraba la ventana).
//
// La solución es un techo por llamada: al vencer, esa llamada se abandona y se
// devuelve "sin resultados". El trabajo interno no se puede cancelar (la
// extensión corre en otro runtime), pero ya no bloquea ni la agregación ni el
// cierre de la búsqueda.
// ─────────────────────────────────────────────────────────────────────────

const (
	// searchProviderTimeoutFanout es el techo de UN proveedor en la búsqueda
	// SÍNCRONA que agrega todo antes de responder (RPC y ruta /search del
	// servidor: PC, web, llamadas sueltas). Acá el techo define cuánto tarda la
	// respuesta, así que tiene que ser corto — pero con margen sobre el catálogo
	// más lento medido (apple-music, 1.9 s en frío) para no perder una fuente
	// que funciona bien solo porque su servidor tenía cola. 3 s deja ese margen
	// y sigue muy por debajo de la ventana global de 4 s.
	searchProviderTimeoutFanout = 3 * time.Second

	// El camino de STREAMING (el que usa la app en el teléfono) NO usa un techo
	// más corto a propósito: usa searchGlobalTimeout, exactamente la ventana que
	// existía antes de todo este trabajo. Así queda garantizado que ningún
	// proveedor se corta antes que antes (cero resultados perdidos) y la
	// ganancia viene de otro lado: el canal se cierra en cuanto todos responden,
	// en vez de esperar siempre a que venza el temporizador. Además la app pinta
	// los resultados apenas llega el primer lote, así que su velocidad percibida
	// no depende de este número.

	// searchFuenteUnicaTimeout es el techo cuando el usuario eligió UNA fuente
	// a propósito. Es más generoso que el del fan-out porque no hay otros
	// proveedores compitiendo y el usuario pidió explícitamente esa fuente;
	// pero sigue acotado para que un proveedor colgado nunca deje la pantalla
	// cargando (antes: 40 s o para siempre).
	searchFuenteUnicaTimeout = 6 * time.Second
)

// resultadoProveedor lleva el valor y si llegó dentro del techo de tiempo.
// El `ok` existe para poder distinguir un resultado vacío legítimo ("este
// proveedor no tiene nada") de un abandono por timeout, sin inventar valores
// centinela en cada tipo.
type resultadoProveedor[T any] struct {
	valor T
	ok    bool
}

// resultadoItems empareja los items de una búsqueda por proveedor con si la
// fuente falló. Existe para poder cronometrar searchProviderItems (Go no deja
// pasar una función de dos retornos a conTimeoutProveedor) y para que el
// llamador tenga en un solo valor las dos cosas que necesita anotar en la
// sesión: los items y si esa fuente llegó a responder.
type resultadoItems struct {
	items []FeedItemGo
	fallo bool
}

// parResultado empareja el (elementos, error) de una búsqueda por proveedor.
// Existe porque Go no permite usar una función de retorno múltiple como
// `func() T`: hay que envolverla en un valor único para poder cronometrarla.
// Es de nivel de paquete porque los tipos locales no pueden usar los
// parámetros de tipo de la función que los contiene.
type parResultado[T any] struct {
	items []T
	err   error
}

// conTimeoutProveedor ejecuta fn con un techo de tiempo. Al vencer devuelve el
// cero de T y ok=false. El pánico de fn se traga aquí para no tumbar la
// búsqueda (los fan-outs ya lo hacían por su cuenta).
//
// Nota de honestidad: el trabajo interno NO se cancela — una extensión corre en
// otro runtime y sigue hasta terminar. Lo que se acota es la espera, no el
// trabajo. En el camino de streaming eso es inocuo (si termina más tarde, sus
// items se descartan por generación); en el síncrono, la respuesta no se hace
// esperar.
func conTimeoutProveedor[T any](d time.Duration, fn func() T) resultadoProveedor[T] {
	ch := make(chan T, 1) // buffer 1: el emisor nunca se queda bloqueado
	go func() {
		defer func() {
			if rec := recover(); rec != nil {
				ch <- *new(T)
			}
		}()
		ch <- fn()
	}()

	timer := time.NewTimer(d)
	defer timer.Stop()
	select {
	case v := <-ch:
		return resultadoProveedor[T]{valor: v, ok: true}
	case <-timer.C:
		var zero T
		return resultadoProveedor[T]{valor: zero, ok: false}
	}
}
