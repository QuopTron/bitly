package extensions

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"sync"
	"time"

	"github.com/dop251/goja"
	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

// registerFileSegments expone file.downloadSegments, el descargador paralelo de
// segmentos que Tidal necesita para sus manifiestos DASH.
//
// Un track de Tidal llega como un init segment + N segmentos de media. La
// versión anterior los bajaba de a uno desde JS (con un round-trip al sandbox
// por segmento y un archivo temporal por cada uno), lo que dejaba la descarga
// serializada. Acá se bajan en paralelo (maxParallel) y se concatenan en orden.
//
// persistentCheckpoint: cada segmento se guarda en <salida>.partN y, si el
// intento se reintenta, se reutiliza lo ya bajado. Los partes se borran solo al
// terminar bien, así una descarga cortada se reanuda en vez de empezar de cero.
//
// Se conecta con: la extensión tidal-web (bundled_extensions/tidal-web/index.js,
// función downloadManifestSegments).
// Parte del flujo: descarga de Tidal (armado del archivo final desde segmentos).
func registerFileSegments(s *Sandbox, fileObj *goja.Object) {
	vm := s.VM

	fileObj.Set("downloadSegments", func(call goja.FunctionCall) goja.Value {
		urls := jsStringSlice(call.Argument(0).Export())
		if len(urls) == 0 {
			return vm.ToValue(map[string]interface{}{"success": false, "error": "no segment urls"})
		}
		outputPath := call.Argument(1).String()
		outFull, resErr := resolverRuta(s, outputPath)
		if resErr != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": resErr.Error()})
		}

		// Las opciones se leen del objeto JS sin exportarlo del todo: necesitamos
		// el valor CRUDO de onProgress para poder envolverlo como callback.
		opts := map[string]interface{}{}
		var progressValue goja.Value
		if o, ok := call.Argument(2).(*goja.Object); ok {
			if exported := o.Export(); exported != nil {
				if m, ok := exported.(map[string]interface{}); ok {
					opts = m
				}
			}
			progressValue = o.Get("onProgress")
		}

		headers := map[string]string{}
		if h, ok := opts["headers"].(map[string]interface{}); ok {
			for k, v := range h {
				headers[k] = fmt.Sprint(v)
			}
		}

		maxParallel := int(runtimeOptInt64(opts, "maxParallel", 4))
		if maxParallel < 1 {
			maxParallel = 1
		}
		if maxParallel > len(urls) {
			maxParallel = len(urls)
		}
		checkpoint := runtimeOptBool(opts, "persistentCheckpoint", false)
		progress := newJSCallback(vm, progressValue, 150)

		if err := os.MkdirAll(filepath.Dir(outFull), 0755); err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("mkdir: %v", err)})
		}

		client := &http.Client{
			Transport: &http.Transport{
				DialContext:           httpclient.NewDoHDialContext(),
				ResponseHeaderTimeout: 30 * time.Second,
			},
		}

		type segResult struct {
			index int
			size  int64
			err   error
		}

		partPath := func(i int) string { return fmt.Sprintf("%s.part%d", outFull, i) }

		// Los workers solo tocan archivos y el canal; ningún callback JS se
		// invoca desde ellos (goja no es thread-safe).
		results := make(chan segResult, len(urls))
		sem := make(chan struct{}, maxParallel)
		var wg sync.WaitGroup

		for i, u := range urls {
			wg.Add(1)
			go func(i int, u string) {
				defer wg.Done()
				sem <- struct{}{}
				defer func() { <-sem }()

				dest := partPath(i)
				if checkpoint {
					if st, err := os.Stat(dest); err == nil && st.Size() > 0 {
						results <- segResult{i, st.Size(), nil}
						return
					}
				}
				n, err := descargarSegmento(client, u, dest, headers)
				results <- segResult{i, n, err}
			}(i, u)
		}

		go func() {
			wg.Wait()
			close(results)
		}()

		sizes := make([]int64, len(urls))
		completed := 0
		var written int64
		var firstErr error
		for r := range results {
			if r.err != nil {
				if firstErr == nil {
					firstErr = fmt.Errorf("segment %d: %w", r.index, r.err)
				}
				continue
			}
			sizes[r.index] = r.size
			completed++
			written += r.size
			progress.call(written, 0, completed, len(urls))
		}

		var total int64
		for _, sz := range sizes {
			total += sz
		}

		if firstErr != nil {
			// Los partes se conservan: el próximo intento reanuda en vez de
			// volver a bajar todo.
			progress.callFinal(written, total, completed, len(urls))
			return vm.ToValue(map[string]interface{}{
				"success":   false,
				"error":     firstErr.Error(),
				"completed": completed,
				"total":     len(urls),
			})
		}

		out, err := os.Create(outFull)
		if err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("create: %v", err)})
		}
		var merged int64
		for i := range urls {
			src, err := os.Open(partPath(i))
			if err != nil {
				out.Close()
				return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("open part %d: %v", i, err)})
			}
			n, err := io.Copy(out, src)
			src.Close()
			if err != nil {
				out.Close()
				return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("merge part %d: %v", i, err)})
			}
			merged += n
			progress.call(merged, total, completed, len(urls))
		}
		if err := out.Close(); err != nil {
			return vm.ToValue(map[string]interface{}{"success": false, "error": fmt.Sprintf("close: %v", err)})
		}

		// Solo al terminar bien se limpian los partes (checkpoint consumido).
		for i := range urls {
			_ = os.Remove(partPath(i))
		}

		progress.callFinal(merged, total, len(urls), len(urls))
		return vm.ToValue(map[string]interface{}{
			"success":  true,
			"path":     outFull,
			"size":     merged,
			"segments": len(urls),
		})
	})
}

// descargarSegmento baja un segmento a [dest] verificando que el cuerpo llegó
// completo (un CDN que corta la conexión puede terminar io.Copy sin error y
// dejar el archivo truncado, lo que después corrompe el audio).
func descargarSegmento(client *http.Client, url, dest string, headers map[string]string) (int64, error) {
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return 0, fmt.Errorf("request: %w", err)
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	resp, err := client.Do(req)
	if err != nil {
		return 0, fmt.Errorf("http: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return 0, fmt.Errorf("HTTP %d", resp.StatusCode)
	}

	f, err := os.Create(dest)
	if err != nil {
		return 0, fmt.Errorf("create: %w", err)
	}
	written, err := io.Copy(f, resp.Body)
	closeErr := f.Close()
	if err != nil {
		_ = os.Remove(dest)
		return written, fmt.Errorf("copy: %w", err)
	}
	if closeErr != nil {
		_ = os.Remove(dest)
		return written, fmt.Errorf("close: %w", closeErr)
	}
	if resp.ContentLength >= 0 && written != resp.ContentLength {
		_ = os.Remove(dest)
		return written, fmt.Errorf("truncated segment: got %d of %d bytes", written, resp.ContentLength)
	}
	return written, nil
}

// jsStringSlice convierte un array JS (exportado como []interface{}) en una
// lista de strings no vacíos, conservando el orden.
func jsStringSlice(exported interface{}) []string {
	arr, ok := exported.([]interface{})
	if !ok {
		return nil
	}
	out := make([]string, 0, len(arr))
	for _, item := range arr {
		s := fmt.Sprint(item)
		if s == "" || s == "<nil>" {
			continue
		}
		out = append(out, s)
	}
	return out
}
