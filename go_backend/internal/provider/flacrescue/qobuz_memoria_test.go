// qobuz_memoria_test.go — La búsqueda COMPARTIDA del id de pista de Qobuz.
//
// Por qué importa: el id de Qobuz lo necesitan DOS canales (el Qobuz firmado y
// el stash-relay) y desde que la resolución los corre en paralelo los dos pedían
// la MISMA búsqueda al mismo tiempo — dos veces la cuota y dos veces la latencia
// por una sola respuesta. Estos tests fijan que:
//   - los dos se reparten UNA búsqueda (y los dos reciben el id);
//   - la siguiente vuelta sale de la memoria, sin tocar el catálogo;
//   - y los FALLOS no se comparten: si la búsqueda compartida se cayó, el que
//     esperaba la hace por su cuenta (atar un canal al destino del otro sería
//     perder robustez justo donde el rescate la necesita).
//
// Nunca sale a Internet: todo va contra servidores de prueba firmados.
package flacrescue

import (
	"context"
	"net/http"
	"net/http/httptest"
	"sync"
	"sync/atomic"
	"testing"
	"time"
) // TestBusquedaDeIDCompartidaPagaUnaSolaPeticion: varios canales piden el id a la
// vez y el catálogo recibe UNA búsqueda. Se usan VARIOS esperando (no dos) porque
// el resultado compartido es un BROADCAST: con un canal de un solo valor, el
// segundo esperando se quedaba colgado para siempre (BUG que este test fija).
func TestBusquedaDeIDCompartidaPagaUnaSolaPeticion(t *testing.T) {
	// La búsqueda tarda a propósito: garantiza que los demás canales lleguen
	// MIENTRAS la primera sigue en vuelo (que es el caso real de la carrera).
	srv, nBusqueda, _ := servidorQobuz(t, "USUM72500857", true, 150*time.Millisecond)
	defer srv.Close()

	c := clienteConQobuz(srv.URL)

	const canales = 6
	var (
		wg   sync.WaitGroup
		mu   sync.Mutex
		ids  []string
		errs []error
	)
	for i := 0; i < canales; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			id, err := c.trackIDPorISRCCompartido(context.Background(), srv.URL, "USUM72500857")
			mu.Lock()
			ids = append(ids, id)
			errs = append(errs, err)
			mu.Unlock()
		}()
	}
	// Un esperando colgado se ve como un test que no vuelve: se lo acota.
	esperado := make(chan struct{})
	go func() { wg.Wait(); close(esperado) }()
	select {
	case <-esperado:
	case <-time.After(5 * time.Second):
		t.Fatal("los canales que esperan la búsqueda compartida no volvieron")
	}

	if len(ids) != canales {
		t.Fatalf("volvieron %d de %d canales", len(ids), canales)
	}
	for i, err := range errs {
		if err != nil || ids[i] != "312055179" {
			t.Fatalf("canal %d no recibió el id compartido: %q / %v", i, ids[i], err)
		}
	}
	if n := *nBusqueda; n != 1 {
		t.Fatalf("búsquedas = %d, se esperaba 1 (el id se comparte, no se paga %d veces)", n, canales)
	}

	// Otra vuelta, ya en serie y con el ISRC en minúsculas: sale de la memoria
	// (la clave se normaliza), sin ninguna petición nueva.
	if _, err := c.trackIDPorISRCCompartido(context.Background(), srv.URL, "usum72500857"); err != nil {
		t.Fatalf("la segunda vuelta falló: %v", err)
	}
	if n := *nBusqueda; n != 1 {
		t.Fatalf("la memoria de ids no evitó la búsqueda: %d", n)
	}
}

// servidorQobuzQueFalla cuenta las búsquedas y las rechaza.
func servidorQobuzQueFalla() (*httptest.Server, *atomic.Int64) {
	var busquedas atomic.Int64
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/catalog/search" {
			busquedas.Add(1)
		}
		w.WriteHeader(http.StatusInternalServerError)
		_, _ = w.Write([]byte(`{}`))
	}))
	return srv, &busquedas
}

// TestBusquedaDeIDNoComparteFallos: el que esperaba no hereda el fallo del otro.
func TestBusquedaDeIDNoComparteFallos(t *testing.T) {
	srv, busquedas := servidorQobuzQueFalla()
	defer srv.Close()

	// El respaldo del canal (la API "oficial" en los tests) apunta al MISMO
	// servidor: si no, cada intento pagaría además una caída de red al respaldo
	// y no se podría medir "una petición por intento".
	previo := qobuzAPIBaseOficial
	qobuzAPIBaseOficial = srv.URL
	t.Cleanup(func() { qobuzAPIBaseOficial = previo })

	c := clienteConQobuz(srv.URL)

	var wg sync.WaitGroup
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if id, err := c.trackIDPorISRCCompartido(context.Background(), srv.URL, "USUM72500857"); err == nil || id != "" {
				t.Errorf("con la búsqueda caída no puede haber id: %q / %v", id, err)
			}
		}()
	}
	wg.Wait()

	// Los DOS intentaron por su cuenta: si el fallo se compartiera, habría una
	// sola petición.
	if n := busquedas.Load(); n != 2 {
		t.Fatalf("búsquedas = %d, se esperaban 2 (un fallo compartido ataría un canal al otro)", n)
	}
}

// TestOlvidarIDsQobuzVaciaLaMemoria: cambiar las credenciales puede apuntar a
// otro catálogo, así que los ids memorizados se tiran.
func TestOlvidarIDsQobuzVaciaLaMemoria(t *testing.T) {
	c := clienteConQobuz("http://127.0.0.1:1")
	c.idsQobuz["USUM72500857"] = "312055179"
	c.olvidarIDsQobuz()
	if id := c.idsQobuz["USUM72500857"]; id != "" {
		t.Fatalf("la memoria quedó con %q tras cambiar las credenciales", id)
	}
}
