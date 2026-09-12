// stress_concurrencia_test.go — Pruebas de ESTRÉS de los caminos concurrentes
// del streaming.
//
// Por qué existen aparte de las funcionales: una prueba funcional usa un
// cliente a la vez, así que nunca toca el estado compartido (el tamaño de
// trozo configurable, la caché de chunks) desde dos goroutines. Acá se fuerza
// justamente ese solapamiento, que es donde una carrera de datos vive. El
// valor real de estas pruebas lo da el detector de carreras (`go test -race`,
// o scripts/race_windows.sh en Windows).
//
// Se conecta con: cache.go (SetChunkSize y la caché), server_chunk.go
// (StreamChunk) y server_http.go (el servidor de stream).
// Parte del flujo: entrega del audio al reproductor.
package streaming

import (
	"bytes"
	"fmt"
	"io"
	"net/http"
	"sync"
	"testing"
	"time"
)

// TestStressTamanoDeTrozoSeCambiaMientrasSeLee es una carrera REAL y no
// hipotética: el usuario cambia el tamaño de trozo en Ajustes (que llama a
// SetChunkSize) mientras suena una canción, y el handler de chunks LEE ese
// valor para calcular el índice del chunk. Antes de pasar el valor a
// atomic.Int64, este test marcaba carrera de datos con -race.
func TestStressTamanoDeTrozoSeCambiaMientrasSeLee(t *testing.T) {
	// Estado de paquete: se restaura para no contaminar las demás pruebas.
	defer SetChunkSize(256 * 1024)

	datos := make([]byte, 256*1024)
	for i := range datos {
		datos[i] = byte(i % 251)
	}
	origen := origenConRango(t, datos, nil)
	defer origen.Close()

	s := NewStreamer()

	const lectores = 6
	parar := make(chan struct{})
	errores := make(chan string, lectores)
	var wg sync.WaitGroup

	for i := 0; i < lectores; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			offset := int64((i % 4) * 64 * 1024)
			for {
				select {
				case <-parar:
					return
				default:
				}
				bloque, err := s.StreamChunk(origen.URL, offset, 64*1024)
				if err != nil {
					errores <- err.Error()
					return
				}
				if len(bloque) == 0 {
					errores <- "trozo vacío"
					return
				}
			}
		}(i)
	}

	// El ajuste se cambia en vivo durante una ventana fija, para garantizar
	// que las escrituras se solapen con las lecturas de verdad.
	tamanos := []int{32 * 1024, 64 * 1024, 128 * 1024, 256 * 1024}
	fin := time.Now().Add(300 * time.Millisecond)
	for i := 0; time.Now().Before(fin); i++ {
		SetChunkSize(tamanos[i%len(tamanos)])
	}

	close(parar)
	wg.Wait()
	close(errores)
	for e := range errores {
		t.Errorf("lector concurrente: %s", e)
	}
}

// TestStressCacheDeStreamingBajoConcurrencia machaca la caché de chunks desde
// varias goroutines a la vez (Add/Get/ChunkCount/Clear sobre las mismas y
// distintas pistas). Es el estado compartido que un reproductor con varias
// canciones encoladas toca sin parar.
func TestStressCacheDeStreamingBajoConcurrencia(t *testing.T) {
	sc := NewCache()

	const goroutines = 8
	const pistas = 3
	var wg sync.WaitGroup

	for g := 0; g < goroutines; g++ {
		wg.Add(1)
		go func(g int) {
			defer wg.Done()
			pista := fmt.Sprintf("pista-%d", g%pistas)
			for i := 0; i < 300; i++ {
				sc.Add(pista, Chunk{Data: []byte{byte(i)}, Index: i, Size: 1})
				_, _ = sc.Get(pista, i%8)
				_ = sc.ChunkCount(pista)
				if i%50 == 0 {
					sc.Clear(pista)
				}
			}
		}(g)
	}

	listo := make(chan struct{})
	go func() { wg.Wait(); close(listo) }()
	select {
	case <-listo:
	case <-time.After(30 * time.Second):
		t.Fatal("la caché de streaming se colgó bajo concurrencia")
	}
}

// TestStressAbortosYElStreamSiguienteEsExacto arranca varios clientes que
// cortan la conexión a mitad de camino y después exige que un stream completo
// siga saliendo byte a byte idéntico. Un aborto mal gestionado (goroutine que
// no termina, estado compartido a medio escribir) o cuelga o contamina el
// stream siguiente, y las dos cosas se ven acá.
func TestStressAbortosYElStreamSiguienteEsExacto(t *testing.T) {
	datos := make([]byte, 3*16384+500)
	for i := range datos {
		datos[i] = byte(i % 199)
	}
	origen := origenConRango(t, datos, nil)
	defer origen.Close()

	s := NewStreamer()
	s.trozoFijo = 16384
	base, err := s.StartServer(0)
	if err != nil {
		t.Fatal(err)
	}
	defer s.StopServer()

	const abortos = 6
	var wg sync.WaitGroup
	for i := 0; i < abortos; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			resp, err := http.Get(base + "/stream?url=" + origen.URL)
			if err != nil {
				return
			}
			// Se lee un poco y se corta: el servidor queda a mitad de bombeo.
			buf := make([]byte, 1024)
			_, _ = io.ReadFull(resp.Body, buf)
			_ = resp.Body.Close()
		}()
	}

	listo := make(chan struct{})
	go func() { wg.Wait(); close(listo) }()
	select {
	case <-listo:
	case <-time.After(30 * time.Second):
		t.Fatal("los abortos se colgaron")
	}

	// Y después de los abortos, un stream completo debe seguir siendo exacto.
	resp, err := http.Get(base + "/stream?url=" + origen.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	cuerpo, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(cuerpo, datos) {
		t.Fatalf("tras los abortos el stream salió corrupto: %d bytes vs %d esperados", len(cuerpo), len(datos))
	}
}
