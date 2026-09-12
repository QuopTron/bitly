// descarga_paralela_stress_test.go — Pruebas de ESTRÉS de la descarga por
// rangos bajo concurrencia real.
//
// Las pruebas funcionales validan UN archivo a la vez. Acá se fuerza lo que
// pasa en la app cuando el usuario baja un álbum: VARIAS descargas en paralelo,
// cada una con sus propias conexiones, todas escribiendo en disco a la vez.
//
// Dos propiedades se fijan acá:
//  1. cada archivo sale byte a byte idéntico aunque las descargas se pisen en
//     el tiempo (offsets y archivos no se cruzan);
//  2. el callback de progreso se entrega SERIALIZADO. El tracker de la app no
//     es thread-safe y está documentado que el llamador no tiene por qué
//     hacerlo: si el mutex se quitara, -race marcaría carrera sobre el contador
//     de la prueba.
//
// Se conecta con: descarga_paralela.go.
// Parte del flujo: descarga de audio a disco.
package download

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sync"
	"testing"
	"time"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

// TestStressDescargasParalelasSimultaneas lanza varias descargas del MISMO
// origen a la vez, cada una con 4 conexiones, y exige que todos los archivos
// queden exactos.
func TestStressDescargasParalelasSimultaneas(t *testing.T) {
	// Por encima de umbralParalelo (4 MB) para que se paralelice de verdad.
	datos := make([]byte, 6<<20)
	for i := range datos {
		datos[i] = byte(i % 253)
	}
	var pico int32
	origen := origenRangos(t, datos, true, &pico)
	defer origen.Close()

	ctx, cancelar := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancelar()

	info := sondearOrigen(ctx, httpclient.NewMediaClient(), origen.URL)
	if !info.soporta {
		t.Fatalf("el origen de prueba debía permitir paralelizar (total=%d, rangos=%v)", info.total, info.rangos)
	}

	const descargas = 4
	dir := t.TempDir()
	errores := make(chan string, descargas)
	var wg sync.WaitGroup

	for i := 0; i < descargas; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			destino := filepath.Join(dir, fmt.Sprintf("pista-%d.bin", i))

			// Contador SIN candado a propósito: el mutex de descargarEnParalelo
			// es el que debe serializar las llamadas. Si se quitara, -race
			// marcaría esta escritura.
			var llamadas int
			err := descargarEnParalelo(ctx, origen.URL, destino, info, 4, func(done, total int64) {
				if done < 0 || done > total {
					errores <- fmt.Sprintf("progreso imposible: %d de %d", done, total)
					return
				}
				llamadas++
			})
			if err != nil {
				errores <- fmt.Sprintf("descarga %d: %v", i, err)
				return
			}
			if llamadas == 0 {
				errores <- fmt.Sprintf("descarga %d: nunca reportó progreso", i)
				return
			}

			obtenido, err := os.ReadFile(destino)
			if err != nil {
				errores <- fmt.Sprintf("descarga %d: leer destino: %v", i, err)
				return
			}
			if !bytes.Equal(obtenido, datos) {
				errores <- fmt.Sprintf("descarga %d: archivo distinto (%d bytes vs %d)", i, len(obtenido), len(datos))
			}
		}(i)
	}

	listo := make(chan struct{})
	go func() { wg.Wait(); close(listo) }()
	select {
	case <-listo:
	case <-time.After(60 * time.Second):
		t.Fatal("las descargas simultáneas se colgaron")
	}
	close(errores)

	for e := range errores {
		t.Error(e)
	}
}
