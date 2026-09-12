package provider

import "sync"

// Single-flight de la caché de metadata: si dos pedidos IDÉNTICOS están en
// vuelo al mismo tiempo, el segundo espera al primero en vez de duplicar la
// llamada.
//
// Por qué importa (y por qué la caché sola no alcanza): la caché se consulta
// ANTES de llamar, así que resuelve lo repetido en el tiempo, pero no lo
// simultáneo. Y en esta app lo simultáneo es lo normal: la búsqueda del usuario
// dispara la precarga de detalles, "Todas" consulta al proveedor mientras el
// buscador ya lo hizo, y teclear rápido reemite la misma consulta. Como el
// sandbox JS serializa, cada duplicado no es solo una llamada de red de más:
// es una llamada que se ENCOLA detrás de la primera y retrasa lo que el usuario
// sí está mirando.
//
// Comportamiento de un seguidor: recibe el mismo resultado que el líder (una
// COPIA, para no compartir estructuras mutables) o el mismo error. Compartir el
// error es deliberado: repetir una fuente caída N veces la castiga N veces sin
// que el usuario gane nada.
//
// Sin colgarse: el líder cierra el vuelo siempre, incluso si la llamada entra
// en pánico (por eso el cierre va en un defer). Un vuelo que nadie cierra
// dejaría a los seguidores esperando para siempre.
//
// Se conecta con: extension_provider_call.go (callOp lo usa) y metadata_cache.go
// (mismas claves que la caché).
// Parte del flujo: metadata de proveedores (búsqueda, detalle, feed).

// vueloMetadata es una llamada en curso que otros pedidos idénticos esperan.
type vueloMetadata struct {
	// listo se cierra cuando el líder terminó; el cierre después de escribir
	// valor/err es lo que garantiza que los seguidores vean lo publicado.
	listo chan struct{}
	valor interface{}
	err   error
}

var (
	vuelosMu sync.Mutex
	vuelos   = map[string]*vueloMetadata{}
)

// registrarVueloCache intenta volverse el líder del vuelo [clave].
//
// Devuelve true si este goroutine es el líder (debe hacer la llamada real) o
// false junto con el vuelo existente, que hay que esperar.
func registrarVueloCache(clave string) (bool, *vueloMetadata) {
	vuelosMu.Lock()
	defer vuelosMu.Unlock()

	if enCurso, ok := vuelos[clave]; ok {
		return false, enCurso
	}
	nuevo := &vueloMetadata{listo: make(chan struct{})}
	vuelos[clave] = nuevo
	return true, nuevo
}

// cerrarVueloCache publica el resultado del líder y despierta a los seguidores.
// Es seguro llamarlo dos veces: el segundo llamado no encuentra el vuelo y no
// hace nada (no cierra el canal dos veces).
func cerrarVueloCache(clave string, valor interface{}, err error) {
	vuelosMu.Lock()
	enCurso, ok := vuelos[clave]
	if ok {
		enCurso.valor = valor
		enCurso.err = err
		delete(vuelos, clave)
	}
	vuelosMu.Unlock()

	if ok {
		close(enCurso.listo)
	}
}

// llamarConVuelo ejecuta la llamada a la extensión colapsando los pedidos
// idénticos simultáneos en una sola llamada real.
//
// Los métodos no cacheables (descargas, streams) van directo: su resultado
// depende del momento y no pueden compartirse ni esperarse entre sí.
func (p *ExtensionProvider) llamarConVuelo(cacheable bool, clave, method string, args []interface{}) (interface{}, error) {
	if !cacheable {
		return p.runtime.CallMethod(p.extID, method, args...)
	}

	lider, vuelo := registrarVueloCache(clave)
	if !lider {
		<-vuelo.listo
		// Copia: el valor del líder lo van a recibir todos los consumidores, y
		// los converters de la app arman structs mutando estos mapas.
		return copiarValorExportado(vuelo.valor), vuelo.err
	}

	var (
		res interface{}
		err error
	)
	// El cierre va en defer para que un pánico no deje a nadie esperando.
	defer func() { cerrarVueloCache(clave, res, err) }()
	res, err = p.runtime.CallMethod(p.extID, method, args...)
	return res, err
}
