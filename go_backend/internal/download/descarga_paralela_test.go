// descarga_paralela_test.go — Pruebas de la descarga por rangos.
//
// Lo crítico de escribir en offsets es que el archivo quede EXACTO: un
// offset mal calculado produce un archivo que "pesa lo correcto" pero
// suena roto. Por eso se compara byte a byte, no solo el tamaño.
//
// Se conecta con: descarga_paralela.go.
// Parte del flujo: descarga de audio a disco.
package download

import (
	"bytes"
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

// origenRangos sirve datos con soporte de Range y registra la concurrencia.
func origenRangos(t *testing.T, datos []byte, soporta bool, pico *int32) *httptest.Server {
	t.Helper()
	var enVuelo int32
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		actual := atomic.AddInt32(&enVuelo, 1)
		for {
			p := atomic.LoadInt32(pico)
			if actual <= p || atomic.CompareAndSwapInt32(pico, p, actual) {
				break
			}
		}
		defer atomic.AddInt32(&enVuelo, -1)

		total := int64(len(datos))
		desde, hasta := int64(0), total-1

		if rh := r.Header.Get("Range"); strings.HasPrefix(rh, "bytes=") && soporta {
			parte := strings.TrimPrefix(rh, "bytes=")
			i := strings.IndexByte(parte, '-')
			if i >= 0 {
				if v, err := strconv.ParseInt(parte[:i], 10, 64); err == nil {
					desde = v
				}
				if j := i + 1; j < len(parte) {
					if v, err := strconv.ParseInt(parte[j:], 10, 64); err == nil {
						hasta = v
					}
				}
			}
			w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", desde, hasta, total))
			w.WriteHeader(http.StatusPartialContent)
		} else {
			w.WriteHeader(http.StatusOK)
		}

		if desde > hasta || desde >= total {
			return
		}
		if hasta >= total {
			hasta = total - 1
		}
		// pequeño respiro para que dos tramos puedan solaparse de verdad
		time.Sleep(20 * time.Millisecond)
		_, _ = w.Write(datos[desde : hasta+1])
	}))
}

// TestDescargaParalelaEsByteExacta: el archivo final debe ser idéntico.
func TestDescargaParalelaEsByteExacta(t *testing.T) {
	// > umbralParalelo para que el sondeo habilite el camino paralelo.
	datos := make([]byte, umbralParalelo+12345)
	for i := range datos {
		datos[i] = byte(i % 251)
	}
	var pico int32
	origen := origenRangos(t, datos, true, &pico)
	defer origen.Close()

	dir := t.TempDir()
	destino := filepath.Join(dir, "audio.flac")

	info := sondearOrigen(context.Background(), nuevoClientePrueba(), origen.URL)
	if !info.soporta {
		t.Fatalf("el origen debía habilitar el paralelo: %+v", info)
	}

	var visto int64
	err := descargarEnParalelo(context.Background(), origen.URL, destino, info, 4,
		func(done, total int64) { atomic.StoreInt64(&visto, done) })
	if err != nil {
		t.Fatalf("descarga paralela falló: %v", err)
	}

	obtenido, err := os.ReadFile(destino)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(obtenido, datos) {
		t.Fatalf("archivo distinto al origen: %d vs %d bytes", len(obtenido), len(datos))
	}
	if atomic.LoadInt64(&visto) != int64(len(datos)) {
		t.Errorf("el progreso no llegó al total: %d de %d", visto, len(datos))
	}
}

// TestDescargaParalelaUsaVariasConexiones: si no hay concurrencia real, la
// optimización no sirve de nada.
func TestDescargaParalelaUsaVariasConexiones(t *testing.T) {
	datos := make([]byte, umbralParalelo+65536)
	var pico int32
	origen := origenRangos(t, datos, true, &pico)
	defer origen.Close()

	dir := t.TempDir()
	info := sondearOrigen(context.Background(), nuevoClientePrueba(), origen.URL)
	if err := descargarEnParalelo(context.Background(), origen.URL,
		filepath.Join(dir, "a.bin"), info, 4, func(_, _ int64) {}); err != nil {
		t.Fatal(err)
	}
	if atomic.LoadInt32(&pico) < 2 {
		t.Errorf("no hubo paralelismo real (pico de conexiones = %d)", pico)
	}
}

// TestSinRangosNoSeParaleliza: si el origen no soporta Range, el sondeo
// debe decir que no y el llamador cae a la descarga secuencial.
func TestSinRangosNoSeParaleliza(t *testing.T) {
	datos := make([]byte, umbralParalelo)
	var pico int32
	origen := origenRangos(t, datos, false, &pico)
	defer origen.Close()

	info := sondearOrigen(context.Background(), nuevoClientePrueba(), origen.URL)
	if info.soporta {
		t.Errorf("sin Accept-Ranges no debía habilitarse el paralelo: %+v", info)
	}
}

// TestArchivoChicoNoSeParaleliza: por debajo del umbral, una conexión ya
// alcanza y el paralelismo solo agrega overhead.
func TestArchivoChicoNoSeParaleliza(t *testing.T) {
	datos := make([]byte, 1024*1024) // 1 MB < umbral
	var pico int32
	origen := origenRangos(t, datos, true, &pico)
	defer origen.Close()

	info := sondearOrigen(context.Background(), nuevoClientePrueba(), origen.URL)
	if info.soporta {
		t.Errorf("un archivo chico no debía paralelizarse: %+v", info)
	}
	if info.total != int64(len(datos)) {
		t.Errorf("tamaño mal sondeado: %d vs %d", info.total, len(datos))
	}
}

// TestTramoIncompletoFalla: si un tramo no llega completo, NO se puede
// dar por buena la descarga (mejor fallar que entregar audio roto).
func TestTramoIncompletoFalla(t *testing.T) {
	datos := make([]byte, umbralParalelo+4096)
	origen := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		total := int64(len(datos))
		desde, hasta := int64(0), total-1
		if rh := r.Header.Get("Range"); strings.HasPrefix(rh, "bytes=") {
			parte := strings.TrimPrefix(rh, "bytes=")
			i := strings.IndexByte(parte, '-')
			if i >= 0 {
				if v, err := strconv.ParseInt(parte[:i], 10, 64); err == nil {
					desde = v
				}
				if j := i + 1; j < len(parte) {
					if v, err := strconv.ParseInt(parte[j:], 10, 64); err == nil {
						hasta = v
					}
				}
			}
			w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", desde, hasta, total))
			w.WriteHeader(http.StatusPartialContent)
		}
		if hasta >= total {
			hasta = total - 1
		}
		if desde > 0 {
			// El segundo tramo en adelante manda MENOS de lo prometido.
			_, _ = w.Write(datos[desde : desde+(hasta-desde)/2])
			return
		}
		_, _ = w.Write(datos[desde : hasta+1])
	}))
	defer origen.Close()

	dir := t.TempDir()
	info := sondearOrigen(context.Background(), nuevoClientePrueba(), origen.URL)
	err := descargarEnParalelo(context.Background(), origen.URL,
		filepath.Join(dir, "roto.bin"), info, 4, func(_, _ int64) {})
	if err == nil {
		t.Error("un tramo incompleto debía fallar, no entregarse como válido")
	}
}

func nuevoClientePrueba() *http.Client {
	return &http.Client{Timeout: 20 * time.Second}
}
