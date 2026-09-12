// server_pipeline_test.go — Pruebas del proxy de streaming con lectura
// adelantada.
//
// La lectura adelantada es una optimización con un riesgo real: si el
// trozo que se adelanta no arranca exactamente donde terminó el
// anterior, el audio sale con un HUECO o con bytes DUPLICADOS (se oye
// como un salto). Por eso lo primero que se prueba acá es que los bytes
// lleguen idénticos al origen, y solo después que se adelante de verdad.
//
// Se conecta con: server_stream.go (StreamURL) y server_http.go (servidor).
// Parte del flujo: entrega del audio al reproductor.
package streaming

import (
	"bytes"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"
)

// origenConRango sirve [datos] con soporte de Range, registrando cada
// offset pedido y avisando cuando un trozo se termina de enviar.
func origenConRango(t *testing.T, datos []byte, aviso func(desde int64)) *httptest.Server {
	t.Helper()
	var mu sync.Mutex
	pedidos := map[int64]bool{}
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/pedidos" {
			mu.Lock()
			lista := make([]int64, 0, len(pedidos))
			for k := range pedidos {
				lista = append(lista, k)
			}
			mu.Unlock()
			_ = r.Context()
			fmt.Fprintf(w, "%v", lista)
			return
		}

		desde := int64(0)
		hasta := int64(len(datos)) - 1
		if rh := r.Header.Get("Range"); strings.HasPrefix(rh, "bytes=") {
			parte := strings.TrimPrefix(rh, "bytes=")
			i := strings.IndexByte(parte, '-')
			if i > 0 {
				if v, err := strconv.ParseInt(parte[:i], 10, 64); err == nil {
					desde = v
				}
			}
			if j := strings.IndexByte(parte, '-'); j >= 0 && parte[j+1:] != "" {
				if v, err := strconv.ParseInt(parte[j+1:], 10, 64); err == nil {
					hasta = v
				}
			}
		}
		if desde >= int64(len(datos)) {
			w.WriteHeader(http.StatusRequestedRangeNotSatisfiable)
			return
		}
		if hasta >= int64(len(datos)) {
			hasta = int64(len(datos)) - 1
		}

		mu.Lock()
		pedidos[desde] = true
		mu.Unlock()

		trozo := datos[desde : hasta+1]
		w.Header().Set("Content-Type", "audio/mpeg")
		w.Header().Set("Accept-Ranges", "bytes")
		w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", desde, hasta, len(datos)))
		w.WriteHeader(http.StatusPartialContent)

		// Se envía en dos mitades con una pausa: si la lectura adelantada
		// funciona, el trozo siguiente se pide DURANTE esa pausa.
		if aviso != nil && desde == 0 {
			mitad := len(trozo) / 2
			_, _ = w.Write(trozo[:mitad])
			if f, ok := w.(http.Flusher); ok {
				f.Flush()
			}
			time.Sleep(250 * time.Millisecond)
			_, _ = w.Write(trozo[mitad:])
			return
		}
		_, _ = w.Write(trozo)
	}))
}

// TestStreamProxyEntregaBytesExactos es el guard más importante: el audio
// que sale por el proxy debe ser idéntico al del origen, con chunks de
// por medio. Un desfase acá se escucha como un salto.
func TestStreamProxyEntregaBytesExactos(t *testing.T) {
	// 3 trozos completos + un resto corto, para cubrir el final.
	datos := make([]byte, 3*8192+1234)
	for i := range datos {
		datos[i] = byte(i % 251)
	}

	origen := origenConRango(t, datos, nil)
	defer origen.Close()

	s := NewStreamer()
	s.trozoFijo = 8192
	base, err := s.StartServer(0)
	if err != nil {
		t.Fatal(err)
	}
	defer s.StopServer()

	resp, err := http.Get(base + "/stream?url=" + origen.URL)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status = %d", resp.StatusCode)
	}
	recibido, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(recibido, datos) {
		t.Fatalf("los bytes no coinciden: recibidos %d, esperados %d", len(recibido), len(datos))
	}
}

// TestStreamProxyAdelantaElSiguienteTrozo comprueba que la segunda
// petición de rango sale MIENTRAS el origen todavía está enviando la
// primera (que es lo que elimina el hueco en la reproducción).
func TestStreamProxyAdelantaElSiguienteTrozo(t *testing.T) {
	datos := make([]byte, 4*8192)

	var mu sync.Mutex
	trozoCeroTerminado := false
	adelantoAntes := false

	origen := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		desde := int64(0)
		if rh := r.Header.Get("Range"); strings.HasPrefix(rh, "bytes=") {
			parte := strings.TrimPrefix(rh, "bytes=")
			if i := strings.IndexByte(parte, '-'); i > 0 {
				if v, err := strconv.ParseInt(parte[:i], 10, 64); err == nil {
					desde = v
				}
			}
		}
		hasta := desde + 8192 - 1
		if hasta >= int64(len(datos)) {
			hasta = int64(len(datos)) - 1
		}

		if desde == 8192 {
			mu.Lock()
			if !trozoCeroTerminado {
				adelantoAntes = true
			}
			mu.Unlock()
		}

		w.Header().Set("Content-Type", "audio/mpeg")
		w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", desde, hasta, len(datos)))
		w.WriteHeader(http.StatusPartialContent)

		if desde == 0 {
			// Se envía la primera mitad y se espera: el siguiente trozo
			// debería pedirse durante esta espera.
			_, _ = w.Write(datos[desde : desde+4096])
			if f, ok := w.(http.Flusher); ok {
				f.Flush()
			}
			time.Sleep(300 * time.Millisecond)
			_, _ = w.Write(datos[desde+4096 : hasta+1])
			mu.Lock()
			trozoCeroTerminado = true
			mu.Unlock()
			return
		}
		_, _ = w.Write(datos[desde : hasta+1])
	}))
	defer origen.Close()

	s := NewStreamer()
	s.trozoFijo = 8192
	base, err := s.StartServer(0)
	if err != nil {
		t.Fatal(err)
	}
	defer s.StopServer()

	resp, err := http.Get(base + "/stream?url=" + origen.URL)
	if err != nil {
		t.Fatal(err)
	}
	recibido, err := io.ReadAll(resp.Body)
	resp.Body.Close()
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(recibido, datos) {
		t.Fatalf("bytes incorrectos: %d de %d", len(recibido), len(datos))
	}
	mu.Lock()
	adelanto := adelantoAntes
	mu.Unlock()
	if !adelanto {
		t.Error("el segundo trozo debía pedirse ANTES de que el primero termine de enviarse")
	}
}

// TestStreamProxyTrozoCortoNoDejaHueco cubre el caso peligroso: el origen
// contesta un rango más corto de lo pedido pero todavía queda archivo.
// El proxy debe seguir DESDE donde quedó, sin saltarse bytes.
func TestStreamProxyTrozoCortoNoDejaHueco(t *testing.T) {
	datos := make([]byte, 6*4096)
	for i := range datos {
		datos[i] = byte(i % 97)
	}

	origen := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		desde := int64(0)
		if rh := r.Header.Get("Range"); strings.HasPrefix(rh, "bytes=") {
			parte := strings.TrimPrefix(rh, "bytes=")
			if i := strings.IndexByte(parte, '-'); i > 0 {
				if v, err := strconv.ParseInt(parte[:i], 10, 64); err == nil {
					desde = v
				}
			}
		}
		// Deliberadamente devuelve MENOS de lo pedido (2048 en vez de 4096)
		// sin ser el final del archivo.
		hasta := desde + 2048 - 1
		if hasta >= int64(len(datos)) {
			hasta = int64(len(datos)) - 1
		}
		w.Header().Set("Content-Type", "audio/mpeg")
		w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", desde, hasta, len(datos)))
		w.WriteHeader(http.StatusPartialContent)
		_, _ = w.Write(datos[desde : hasta+1])
	}))
	defer origen.Close()

	s := NewStreamer()
	s.trozoFijo = 4096
	base, err := s.StartServer(0)
	if err != nil {
		t.Fatal(err)
	}
	defer s.StopServer()

	resp, err := http.Get(base + "/stream?url=" + origen.URL)
	if err != nil {
		t.Fatal(err)
	}
	recibido, err := io.ReadAll(resp.Body)
	resp.Body.Close()
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(recibido, datos) {
		t.Fatalf("trozo corto dejó hueco: recibidos %d, esperados %d", len(recibido), len(datos))
	}
}

// TestStreamProxyVariosA la vez sacude bloqueos: el pipeline usa un canal
// buffered y una goroutine por trozo, así que un error de sincronización se
// manifiesta como un cuelgue o como bytes cruzados entre streams.
//
// (Esta prueba sigue siendo la red de seguridad para el caso de bytes
// cruzados; las carreras de datos las cubre el detector con -race, que en
// Windows corre con scripts/race_windows.sh.)
func TestStreamProxyVariosA(t *testing.T) {
	datos := make([]byte, 2*16384+777)
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

	const clientes = 8
	errores := make(chan string, clientes)
	var wg sync.WaitGroup

	for i := 0; i < clientes; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			resp, err := http.Get(base + "/stream?url=" + origen.URL)
			if err != nil {
				errores <- err.Error()
				return
			}
			defer resp.Body.Close()
			cuerpo, err := io.ReadAll(resp.Body)
			if err != nil {
				errores <- err.Error()
				return
			}
			if !bytes.Equal(cuerpo, datos) {
				errores <- fmt.Sprintf("bytes cruzados: %d vs %d", len(cuerpo), len(datos))
			}
		}()
	}

	// Se espera con límite: si el pipeline se traba, la prueba falla en vez de
	// colgar la suite para siempre.
	listo := make(chan struct{})
	go func() { wg.Wait(); close(listo) }()
	select {
	case <-listo:
	case <-time.After(30 * time.Second):
		t.Fatal("el proxy se colgó con varios streams a la vez")
	}
	close(errores)
	for e := range errores {
		t.Errorf("stream concurrente: %s", e)
	}
}

// TestTamanoDeTrozoPorFuente fija el criterio: YouTube chico, CDN grande.
func TestTamanoDeTrozoPorFuente(t *testing.T) {
	if got := tamanoDeTrozo("https://rr3---sn-x.googlevideo.com/videoplayback?x=1"); got != streamChunkSize {
		t.Errorf("googlevideo debía usar %d, usa %d", streamChunkSize, got)
	}
	if got := tamanoDeTrozo("https://cdns-preview-1.dzcdn.net/stream/abc.mp3"); got != streamChunkSizeCDN {
		t.Errorf("CDN debía usar %d, usa %d", streamChunkSizeCDN, got)
	}
}
