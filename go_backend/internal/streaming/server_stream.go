package streaming

import (
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
)

func (s *Streamer) StreamURL(w http.ResponseWriter, r *http.Request, audioURL string) error {
	// mpv's Range is "bytes=N-" (open-ended); only its start matters — each
	// upstream chunk is bounded by streamChunkSize regardless.
	start := int64(0)
	ranged := false
	if rh := r.Header.Get("Range"); rh != "" && strings.HasPrefix(rh, "bytes=") {
		part := strings.TrimPrefix(rh, "bytes=")
		if i := strings.IndexByte(part, '-'); i > 0 {
			if v, err := strconv.ParseInt(part[:i], 10, 64); err == nil && v >= 0 {
				start = v
				ranged = true
			}
		}
	}

	// Full size + content type from the URL's own params when present
	// (YouTube googlevideo URLs carry clen= and mime=). These are fallbacks;
	// El primer probe del fragmento upstream de abajo puede sobrescribir/completarlos.
	var clen int64
	if u, err := url.Parse(audioURL); err == nil {
		q := u.Query()
		if v := q.Get("clen"); v != "" {
			if n, err := strconv.ParseInt(v, 10, 64); err == nil {
				clen = n
			}
		}
		if mime := q.Get("mime"); mime != "" {
			if dec, err := url.QueryUnescape(mime); err == nil && dec != "" {
				w.Header().Set("Content-Type", dec)
			}
		}
	}

	// Probe the FIRST chunk before committing to any response status/headers.
	// Only after the upstream accepts the range do we answer the client; a
	// dead/expired/403 URL then surfaces as a clean 5xx error (mpv fails
	// loudly and the cubit can react) instead of "200 OK + zero bytes", which
	// mpv reads as EOF-with-no-data and stalls on forever. It also makes the
	// old "headers written from URL params, then upstream died" double-write
	// impossible on the very first fetch.
	// Tamaño de trozo según la fuente: YouTube pide trozos chicos (bot-gate),
	// los CDN de audio aguantan trozos grandes y hacen menos viajes.
	tamano := s.trozoFijo
	if tamano <= 0 {
		tamano = tamanoDeTrozo(audioURL)
	}

	pos := start
	resp, err := s.fetchChunk(audioURL, pos, tamano)
	if err != nil {
		return err
	}

	// Fill gaps from the real upstream response: content type when the URL
	// params didn't carry mime=, and total length when clen= was absent.
	if w.Header().Get("Content-Type") == "" {
		if ct := resp.Header.Get("Content-Type"); ct != "" {
			w.Header().Set("Content-Type", ct)
		}
	}
	// For a 206 partial response resp.ContentLength is only the CHUNK size
	// (512KB), NOT the file's total — using it as `clen` made the proxy tell
	// mpv the whole file was 512KB, so mpv stopped reading at the first chunk
	// and every chunked stream died at exactly that boundary ("partial file"
	// despues ~20s). El total real vive en la cabecera Content-Range
	// ("bytes 0-524287/4048892" — tras la ultima '/').
	if clen == 0 {
		if cr := resp.Header.Get("Content-Range"); cr != "" {
			if i := strings.LastIndexByte(cr, '/'); i >= 0 && i+1 < len(cr) {
				if total, perr := strconv.ParseInt(cr[i+1:], 10, 64); perr == nil && total > 0 {
					clen = total
				}
			}
		}
	}
	if clen == 0 && resp.ContentLength > 0 {
		clen = resp.ContentLength
	}

	w.Header().Set("Accept-Ranges", "bytes")
	switch {
	case ranged && clen > 0:
		w.Header().Set("Content-Length", strconv.FormatInt(clen-start, 10))
		w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", start, clen-1, clen))
		w.WriteHeader(http.StatusPartialContent)
	case clen > 0:
		w.Header().Set("Content-Length", strconv.FormatInt(clen, 10))
		w.WriteHeader(http.StatusOK)
	default:
		w.WriteHeader(http.StatusOK)
	}

	flusher, _ := w.(http.Flusher)
	return s.encadenarConLecturaAdelantada(w, flusher, audioURL, pos, resp, tamano, clen)
}

// trozo trae el resultado (o el error) de una petición de rango adelantada.
type trozo struct {
	resp *http.Response
	err  error
}

// encadenarConLecturaAdelantada entrega el audio al reproductor pidiendo el
// trozo SIGUIENTE mientras todavía se está escribiendo el actual.
//
// Por qué existe: antes el ciclo era "pedir trozo → escribirlo → pedir el
// siguiente". Durante cada ida y vuelta al CDN el reproductor se quedaba sin
// datos, y eso es exactamente lo que se siente como un micro-corte cada pocos
// segundos. Adelantar una petición elimina ese hueco.
func (s *Streamer) encadenarConLecturaAdelantada(
	dst io.Writer, flusher http.Flusher, audioURL string, pos int64,
	actual *http.Response, tamano, total int64,
) error {
	prox := make(chan trozo, 1)
	prefetcheando := false

	// Al salir por cualquier camino (error incluido) no se puede dejar una
	// petición adelantada en vuelo: su cuerpo quedaría sin cerrar y con él la
	// conexión. Se drena y se cierra antes de devolver.
	defer func() {
		if prefetcheando {
			t := <-prox
			if t.resp != nil {
				t.resp.Body.Close()
			}
		}
	}()

	// esperar toma el trozo adelantado y lo deja como el actual.
	esperar := func() error {
		t := <-prox
		prefetcheando = false
		if t.err != nil {
			return t.err
		}
		actual = t.resp
		return nil
	}
	// descartar suelta un trozo adelantado que ya no encaja (el actual vino
	// corto), para no dejar la conexión colgada.
	descartar := func() {
		if !prefetcheando {
			return
		}
		t := <-prox
		if t.resp != nil {
			t.resp.Body.Close()
		}
		prefetcheando = false
	}

	for {
		// Si ya sabemos que queda archivo, el siguiente trozo empieza a bajar
		// AHORA, en paralelo con la escritura de este.
		if !prefetcheando && total > 0 && pos+tamano < total {
			prefetcheando = true
			desde := pos + tamano
			go func() {
				r, err := s.fetchChunk(audioURL, desde, tamano)
				prox <- trozo{resp: r, err: err}
			}()
		}

		n, err := io.Copy(dst, actual.Body)
		actual.Body.Close()
		if flusher != nil {
			flusher.Flush()
		}
		if err != nil {
			return err
		}
		pos += n

		// Camino rápido: el trozo vino completo y el siguiente ya está listo.
		if prefetcheando && n == tamano {
			if err := esperar(); err != nil {
				return err
			}
			if total > 0 && pos >= total {
				return nil
			}
			continue
		}

		// Trozo incompleto: lo adelantado ya no encaja (arrancaba más adelante
		// que donde realmente quedamos) y se descarta.
		descartar()

		if n == 0 {
			return nil
		}
		// Con total conocido, si ya entregamos todo el archivo, listo. Sin
		// total, un trozo más corto de lo pedido es el final.
		if total > 0 {
			if pos >= total {
				return nil
			}
		} else if n != tamano {
			return nil
		}

		// Se continúa secuencialmente DESDE pos: nunca se deja un hueco.
		resp, ferr := s.fetchChunk(audioURL, pos, tamano)
		if ferr != nil {
			return ferr
		}
		actual = resp
	}
}

// StreamChunk fetches a byte range of audio for mobile/AAR use.
