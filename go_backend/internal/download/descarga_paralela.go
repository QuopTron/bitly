// ─────────────────────────────────────────────────────────────
// descarga_paralela.go — Descarga en varias conexiones usando rangos.
//
// Por qué: un FLAC de 30-80 MB por UNA conexión deja la mayor parte del
// ancho de banda sin usar (una sola conexión TCP no llena el enlace en
// cuanto hay latencia). Bajando N rangos en paralelo el archivo llega
// varias veces más rápido.
//
// Cómo: se sondea el tamaño con una petición de 1 byte, se parte el
// archivo en N tramos y cada tramo se escribe DIRECTO en su offset con
// WriteAt (sin buffers intermedios ni archivos temporales por parte).
//
// Seguridad: si el origen no soporta rangos, si no se puede conocer el
// tamaño, o si el archivo es chico, devuelve ok=false y el llamador
// sigue con la descarga secuencial de siempre. Nunca deja el archivo a
// medias: o completa todos los tramos o falla.
//
// Se conecta con: orchestrator_downloadfile.go.
// Parte del flujo: descarga de audio a disco.
// ─────────────────────────────────────────────────────────────

package download

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

const (
	// umbralParalelo: por debajo de esto una conexión ya es más que
	// suficiente y el paralelismo solo agrega overhead.
	umbralParalelo = 4 << 20 // 4 MB
	// conexionesParalelo: cuántos tramos a la vez. Es el mismo orden que
	// usa un navegador; más conexiones empiezan a molestar a los CDN.
	conexionesParalelo = 4
	// bufferTramo: tamaño de lectura de cada conexión.
	bufferTramo = 256 * 1024
)

// sondeo describe lo que el origen dijo sobre el archivo.
type sondeo struct {
	total   int64
	rangos  bool
	tipo    string
	soporta bool
}

// sondearOrigen averigua tamaño y soporte de rangos con una petición de
// 1 byte (más fiable que HEAD: algunos CDN responden mal a HEAD).
func sondearOrigen(ctx context.Context, cliente *http.Client, url string) sondeo {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return sondeo{}
	}
	req.Header.Set("Range", "bytes=0-0")
	resp, err := cliente.Do(req)
	if err != nil {
		return sondeo{}
	}
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 1024))

	s := sondeo{tipo: resp.Header.Get("Content-Type")}
	s.rangos = strings.Contains(strings.ToLower(resp.Header.Get("Accept-Ranges")), "bytes")

	if resp.StatusCode == http.StatusPartialContent {
		s.rangos = true
		// Content-Range: bytes 0-0/12345678
		if cr := resp.Header.Get("Content-Range"); cr != "" {
			if i := strings.LastIndexByte(cr, '/'); i >= 0 && i+1 < len(cr) {
				if total, perr := strconv.ParseInt(cr[i+1:], 10, 64); perr == nil && total > 0 {
					s.total = total
				}
			}
		}
	}
	if s.total <= 0 && resp.StatusCode == http.StatusOK {
		s.total = resp.ContentLength
	}
	s.soporta = s.rangos && s.total >= umbralParalelo
	return s
}

// descargarEnParalelo baja [url] usando [conexiones] tramos simultáneos.
// Devuelve error si algún tramo falla (el llamador decide qué hacer) y
// una bandera que dice si el origen permitía paralelizar.
func descargarEnParalelo(
	ctx context.Context,
	url, destino string,
	info sondeo,
	conexiones int,
	onProgress func(done, total int64),
) error {
	if conexiones < 2 {
		conexiones = conexionesParalelo
	}
	cliente := httpclient.NewMediaClient()

	archivo, err := os.OpenFile(destino, os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return err
	}
	defer archivo.Close()
	if err := archivo.Truncate(info.total); err != nil {
		return err
	}

	tramo := info.total / int64(conexiones)
	if tramo < 1 {
		tramo = info.total
	}

	ctx, cancelar := context.WithCancel(ctx)
	defer cancelar()

	var descargado int64
	var wg sync.WaitGroup
	var primerError atomic.Value
	var unaVez sync.Once
	// El callback de progreso lo entrega el llamador y NO tiene por qué ser
	// seguro para uso concurrente (suele tocar un tracker compartido), así que
	// se serializa acá en vez de exigirle hilos al que llama.
	var progresoMu sync.Mutex

	for i := 0; i < conexiones; i++ {
		desde := int64(i) * tramo
		hasta := desde + tramo - 1
		if i == conexiones-1 {
			hasta = info.total - 1 // el último tramo se queda con el resto
		}
		if desde > hasta {
			continue
		}

		wg.Add(1)
		go func(desde, hasta int64) {
			defer wg.Done()
			err := descargarTramo(ctx, cliente, url, archivo, desde, hasta, func(n int64) {
				actual := atomic.AddInt64(&descargado, n)
				if onProgress != nil {
					progresoMu.Lock()
					onProgress(actual, info.total)
					progresoMu.Unlock()
				}
			})
			if err != nil {
				unaVez.Do(func() {
					primerError.Store(err)
					cancelar() // los demás tramos se enteran y paran
				})
			}
		}(desde, hasta)
	}
	wg.Wait()

	if v := primerError.Load(); v != nil {
		if err, ok := v.(error); ok {
			return err
		}
	}
	// Verificación final: si falta un byte, no se entrega un archivo roto.
	if descargado < info.total {
		return fmt.Errorf("descarga paralela incompleta: %d de %d bytes", descargado, info.total)
	}
	return nil
}

// descargarTramo baja un rango y lo escribe en su offset exacto.
func descargarTramo(
	ctx context.Context,
	cliente *http.Client,
	url string,
	archivo *os.File,
	desde, hasta int64,
	reportar func(int64),
) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("Range", fmt.Sprintf("bytes=%d-%d", desde, hasta))

	resp, err := cliente.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusPartialContent && resp.StatusCode != http.StatusOK {
		return fmt.Errorf("tramo %d-%d: HTTP %d", desde, hasta, resp.StatusCode)
	}

	buf := make([]byte, bufferTramo)
	pos := desde
	for {
		n, rerr := resp.Body.Read(buf)
		if n > 0 {
			if _, werr := archivo.WriteAt(buf[:n], pos); werr != nil {
				return werr
			}
			pos += int64(n)
			reportar(int64(n))
		}
		if rerr == io.EOF {
			break
		}
		if rerr != nil {
			return rerr
		}
	}
	if pos != hasta+1 {
		return fmt.Errorf("tramo %d-%d incompleto (quedó en %d)", desde, hasta, pos)
	}
	return nil
}
