package provider

import (
	"sync"
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/extensions"
)

// Pruebas del single-flight (metadata_cache_vuelo.go).
//
// Junto con las de la caché, acá se fija la propiedad que el usuario percibe:
// pedir lo mismo —a la vez o después— cuesta UNA llamada, no N.
//
// El bucle ocupado de los scripts (Date.now) es lo que hace que el pedido dure:
// sin él la primera llamada terminaría antes de que los seguidores arranquen y
// la prueba no distinguiría "el vuelo coalesció" de "llegaron tarde y pegaron
// en la caché".

const scriptBusquedaLenta = `
var __n = 0;
function searchTracks(q, limit) {
  __n++;
  var fin = Date.now() + 150;
  while (Date.now() < fin) {}
  return [{ id: "t1", name: "Tema", artists: "Artista", album_name: "Album" }];
}
function contarNum() { return __n; }
`

const scriptBusquedaQueFalla = `
var __n = 0;
function searchTracks(q, limit) {
  __n++;
  var fin = Date.now() + 120;
  while (Date.now() < fin) {}
  throw new Error("HTTP 429 for search");
}
function contarNum() { return __n; }
`

// proveedorConScript monta un ExtensionProvider con el JS indicado.
func proveedorConScript(t *testing.T, name, script string) *ExtensionProvider {
	t.Helper()
	rt := extensions.NewRuntime()
	cfg := extensions.DefaultConfig()
	cfg.TimeoutMs = 30000
	if _, err := rt.RunJS(script, name, name, cfg, "."); err != nil {
		t.Fatalf("RunJS: %v", err)
	}
	return NewExtensionProvider(name, name, rt)
}

// llamadasContadas lee el contador que lleva el propio JS.
func llamadasContadas(t *testing.T, p *ExtensionProvider) int {
	t.Helper()
	res, err := p.runtime.CallMethod(p.extID, "contarNum")
	if err != nil {
		t.Fatalf("contarNum: %v", err)
	}
	switch n := res.(type) {
	case int64:
		return int(n)
	case float64:
		return int(n)
	}
	// Un valor de otro tipo significa que el contador no llegó: la prueba no
	// puede afirmar nada, así que se falla en vez de dar por bueno un 0.
	t.Fatalf("contarNum devolvió %T, se esperaba un número", res)
	return 0
}

// lanzarALaVez dispara [n] copias de [fn] lo más juntas posible (barrera) y
// devuelve los errores que hayan reportado, con límite de tiempo para que un
// cuelgue falle en vez de colgar la suite.
func lanzarALaVez(t *testing.T, n int, fn func() string) []string {
	t.Helper()
	iniciar := make(chan struct{})
	errores := make(chan string, n)
	var wg sync.WaitGroup

	for i := 0; i < n; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-iniciar
			if msg := fn(); msg != "" {
				errores <- msg
			}
		}()
	}
	close(iniciar)

	listo := make(chan struct{})
	go func() { wg.Wait(); close(listo) }()
	select {
	case <-listo:
	case <-time.After(30 * time.Second):
		t.Fatal("los pedidos simultáneos se colgaron (¿un vuelo que nadie cerró?)")
	}
	close(errores)

	salida := make([]string, 0, n)
	for e := range errores {
		salida = append(salida, e)
	}
	return salida
}

// TestVueloColapsaBusquedasSimultaneas es el objetivo central: ocho búsquedas
// idénticas a la vez deben costar UNA llamada a la extensión, y todas deben
// recibir resultados.
func TestVueloColapsaBusquedasSimultaneas(t *testing.T) {
	LimpiarCacheMetadata()
	reiniciarEstadoPrecarga()
	defer reiniciarEstadoPrecarga()
	p := proveedorConScript(t, "vuelo-simultaneo", scriptBusquedaLenta)

	errores := lanzarALaVez(t, 8, func() string {
		tracks, err := p.SearchTracks("la misma consulta", 4)
		if err != nil {
			return err.Error()
		}
		if len(tracks) == 0 {
			return "búsqueda sin resultados"
		}
		return ""
	})
	for _, e := range errores {
		t.Errorf("búsqueda simultánea: %s", e)
	}

	if n := llamadasContadas(t, p); n != 1 {
		t.Fatalf("la extensión se llamó %d veces para 8 pedidos idénticos, se esperaba 1", n)
	}
}

// TestVueloPrimitivasCoalescen fija el mecanismo de forma determinista (sin
// depender de tiempos): el segundo registro es seguidor, el cierre lo despierta
// con el valor publicado, y la clave se libera para no dejar una fuga.
func TestVueloPrimitivasCoalescen(t *testing.T) {
	const clave = "clave-de-prueba-coalesce"

	lider, vuelo := registrarVueloCache(clave)
	if !lider {
		t.Fatal("el primer registro debía ser líder")
	}
	seguidor, vueloSeguidor := registrarVueloCache(clave)
	if seguidor {
		t.Fatal("el segundo registro debía ser seguidor, no líder")
	}
	if vuelo != vueloSeguidor {
		t.Fatal("el seguidor debía compartir el vuelo del líder")
	}

	// El seguidor espera: no debe estar listo antes del cierre.
	select {
	case <-vueloSeguidor.listo:
		t.Fatal("el vuelo se cerró antes de que el líder terminara")
	default:
	}

	cerrarVueloCache(clave, map[string]interface{}{"v": "ok"}, nil)

	select {
	case <-vueloSeguidor.listo:
	case <-time.After(2 * time.Second):
		t.Fatal("el seguidor nunca fue despertado")
	}
	if vueloSeguidor.err != nil {
		t.Fatalf("el seguidor recibió error: %v", vueloSeguidor.err)
	}
	m, ok := vueloSeguidor.valor.(map[string]interface{})
	if !ok || m["v"] != "ok" {
		t.Fatalf("el seguidor no recibió el valor publicado: %#v", vueloSeguidor.valor)
	}

	// Cerrado y borrado: la siguiente vez vuelve a haber líder (sin fuga).
	otraVez, _ := registrarVueloCache(clave)
	if !otraVez {
		t.Fatal("la clave quedó registrada tras cerrar el vuelo (fuga en el mapa)")
	}
	cerrarVueloCache(clave, nil, nil)

	// Un cierre doble no debe entrar en pánico (ni cerrar el canal dos veces).
	cerrarVueloCache(clave, nil, nil)
}

// TestVueloLiderQueFallaNoCuelga cubre el peor caso: el líder falla. Los
// seguidores deben recibir el error y terminar, no quedarse esperando un vuelo
// que ya no va a publicar nada.
func TestVueloLiderQueFallaNoCuelga(t *testing.T) {
	LimpiarCacheMetadata()
	reiniciarEstadoPrecarga()
	defer reiniciarEstadoPrecarga()
	p := proveedorConScript(t, "vuelo-falla", scriptBusquedaQueFalla)

	// No se afirma sobre el mensaje: el que llega tarde puede encontrarse el
	// proveedor en cooldown y recibir "sin resultados" en vez del error. Lo que
	// se prueba es que NINGUNO se cuelga.
	errores := lanzarALaVez(t, 6, func() string {
		_, _ = p.SearchTracks("consulta que falla", 4)
		return ""
	})
	if len(errores) != 0 {
		t.Fatalf("no se esperaban mensajes propios de las goroutines: %v", errores)
	}

	// A lo sumo una llamada real: el error del líder se comparte.
	if n := llamadasContadas(t, p); n > 1 {
		t.Fatalf("una fuente caída se llamó %d veces, se esperaba 1", n)
	}
}
