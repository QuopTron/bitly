// descarga_bench_test.go — Medición de la descarga paralela.
//
// Por qué se simula latencia en vez de medir en loopback: en loopback el
// RTT es ~0, así que una sola conexión ya satura y el paralelismo no
// muestra ninguna ventaja. El problema real es que una conexión TCP con
// ~80 ms de RTT y una ventana de recepción limitada deja el ancho de
// banda sin usar; N conexiones reparten el tiempo de espera.
//
// Este test pone una latencia por petición y compara:
//
//	secuencial  = una sola petición, como antes
//	paralelo    = N rangos simultáneos, como ahora
//
// Se conecta con: descarga_paralela.go.
// Parte del flujo: velocidad de descarga de audio.
package download

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"
)

// TestParaleloEsMasRapidoConLatencia mide y exige que el paralelo gane.
func TestParaleloEsMasRapidoConLatencia(t *testing.T) {
	if testing.Short() {
		t.Skip("mide tiempos: se omite en modo corto")
	}

	const latencia = 120 * time.Millisecond
	// 16 MB: suficiente para que la latencia domine sobre el tiempo de CPU.
	datos := make([]byte, 16<<20)

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

		// La latencia se cobra en trozos sucesivos: es lo que hace una
		// ventana TCP chica contra un servidor lejano.
		cuerpo := datos[desde : hasta+1]
		const bloque = 2 << 20
		for off := 0; off < len(cuerpo); off += bloque {
			fin := off + bloque
			if fin > len(cuerpo) {
				fin = len(cuerpo)
			}
			time.Sleep(latencia)
			if _, err := w.Write(cuerpo[off:fin]); err != nil {
				return
			}
		}
	}))
	defer origen.Close()

	dir := t.TempDir()
	cliente := nuevoClientePrueba()

	// ── Secuencial ──
	inicio := time.Now()
	resp, err := cliente.Get(origen.URL)
	if err != nil {
		t.Fatal(err)
	}
	secDest := filepath.Join(dir, "secuencial.bin")
	f, err := os.Create(secDest)
	if err != nil {
		t.Fatal(err)
	}
	if _, err := io.Copy(f, resp.Body); err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	f.Close()
	duracionSecuencial := time.Since(inicio)

	// ── Paralelo ──
	info := sondearOrigen(context.Background(), cliente, origen.URL)
	if !info.soporta {
		t.Fatalf("el origen debía habilitar el paralelo: %+v", info)
	}
	parDest := filepath.Join(dir, "paralelo.bin")
	inicio = time.Now()
	if err := descargarEnParalelo(context.Background(), origen.URL, parDest, info,
		conexionesParalelo, func(_, _ int64) {}); err != nil {
		t.Fatal(err)
	}
	duracionParalela := time.Since(inicio)

	sec, _ := os.ReadFile(secDest)
	par, _ := os.ReadFile(parDest)
	if len(sec) != len(par) {
		t.Fatalf("tamaños distintos: %d vs %d", len(sec), len(par))
	}

	mejora := float64(duracionSecuencial) / float64(duracionParalela)
	t.Logf("16 MB con %v de latencia por bloque:", latencia)
	t.Logf("  secuencial: %8v", duracionSecuencial.Round(time.Millisecond))
	t.Logf("  paralelo  : %8v  (%.1fx más rápido)", duracionParalela.Round(time.Millisecond), mejora)

	if duracionParalela >= duracionSecuencial {
		t.Errorf("el paralelo no fue más rápido: %v vs %v", duracionParalela, duracionSecuencial)
	}
	if mejora < 1.5 {
		t.Errorf("mejora esperada >= 1.5x, se midió %.2fx", mejora)
	}
}
