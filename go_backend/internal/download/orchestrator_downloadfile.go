package download

import (
	"bufio"
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

// downloadToFile streams [url] to disk under [outDir] using a temp file +
// atomic rename, reporting progress via [onProgress]. Supports HTTP Range
// resume: if a partial download exists for the same URL, it sends a Range
// header to resume from where it left off instead of restarting from zero.
func descargarAArchivo(url, outDir string, req Request, title, artist string, onProgress func(done, total int64)) (string, error) {
	if err := os.MkdirAll(outDir, 0755); err != nil {
		return "", err
	}

	ext := detectarExt(url)
	base := req.TrackID
	if base == "" {
		base = req.ItemID
	}
	pista := sanitizarNombreArchivo(base)
	dest := filepath.Join(outDir, pista+ext)
	huella := huellaFuente(url)

	// Busca un parcial REANUDABLE. Tiene que ser de esta misma pista y de esta
	// misma fuente: adoptar el tamaño de otro archivo como offset del Range
	// produce un archivo cosido con dos audios distintos (la canción "arranca
	// desde la mitad"). Ver orchestrator_parciales.go.
	partialPath, existingSize := buscarParcial(outDir, pista, huella, ext)

	// Cliente de MEDIA: sin timeout global (un FLAC grande tarda) y con
	// muchas conexiones reutilizadas por host, que es lo que hace posible
	// tanto la descarga paralela como la reanudación sin reabrir TLS.
	client := httpclient.NewMediaClient()
	var resp *http.Response
	var err error

	// Descarga PARALELA cuando el origen la soporta. Una sola conexión TCP
	// deja la mayor parte del ancho de banda sin usar en cuanto hay latencia,
	// así que un FLAC de decenas de MB llega varias veces más rápido en N
	// tramos. Si el origen no soporta rangos o el archivo es chico, sigue la
	// ruta secuencial de abajo sin cambiar nada.
	if partialPath == "" || existingSize == 0 {
		if info := sondearOrigen(context.Background(), client, url); info.soporta {
			parcial, cerrar := os.CreateTemp(outDir, nombreParcial(pista, huella, ext, true))
			if cerrar == nil {
				tmpParalelo := parcial.Name()
				parcial.Close()
				if perr := descargarEnParalelo(context.Background(), url, tmpParalelo, info,
					conexionesParalelo, onProgress); perr == nil {
					if rerr := os.Rename(tmpParalelo, dest); rerr == nil {
						return dest, nil
					}
				}
				_ = os.Remove(tmpParalelo)
				log.Printf("[download] paralelo no sirvió para %s, se usa secuencial", base)
			}
		}
	}

	if partialPath != "" && existingSize > 0 {
		// Attempt resume with Range header.
		reqHTTP, _ := http.NewRequest("GET", url, nil)
		reqHTTP.Header.Set("Range", fmt.Sprintf("bytes=%d-", existingSize))
		resp, err = client.Do(reqHTTP)
		if err == nil && resp.StatusCode == http.StatusPartialContent {
			// Server supports Range: append to the existing partial file.				log.Printf("[download] resuming from byte %d for %s", existingSize, base)
			// Se le pasa el destino FINAL explícito: antes lo deducía del
			// nombre del temporal y el archivo quedaba con un nombre
			// aleatorio (dl-7283645.flac → 7283645.flac) en vez del de la
			// pista, así que el reproductor y StreamCacheFile no lo veían.
			return anexarAArchivo(dest, partialPath, resp, existingSize, onProgress)
		}
		// El servidor no soporta Range o devolvio error — se cae a una
		// descarga completa, descartando el parcial.
		if resp != nil {
			resp.Body.Close()
		}
		log.Printf("[download] resume not supported (status=%d), restarting from zero for %s",
			func() int {
				if resp != nil {
					return resp.StatusCode
				}
				return 0
			}(), base)
		_ = os.Remove(partialPath)
		partialPath = ""
		existingSize = 0
	}

	// Full download from zero.
	resp, err = client.Get(url)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("HTTP %d al obtener stream", resp.StatusCode)
	}

	tmp, err := os.CreateTemp(outDir, nombreParcial(pista, huella, ext, false))
	if err != nil {
		return "", err
	}
	tmpPath := tmp.Name()
	defer func() {
		if _, statErr := os.Stat(tmpPath); statErr == nil {
			os.Remove(tmpPath)
		}
	}()

	// Escritura con buffer grande: con 64 KB de lectura + write() crudo el
	// costo de syscalls se nota en archivos grandes. 512 KB de lectura y un
	// bufio.Writer encima reducen mucho los viajes al kernel.
	var done int64
	buf := make([]byte, 512*1024)
	escritor := bufio.NewWriterSize(tmp, 512*1024)
	for {
		n, rerr := resp.Body.Read(buf)
		if n > 0 {
			if _, werr := escritor.Write(buf[:n]); werr != nil {
				tmp.Close()
				return "", werr
			}
			done += int64(n)
			onProgress(done, resp.ContentLength)
		}
		if rerr == io.EOF {
			break
		}
		if rerr != nil {
			tmp.Close()
			return "", rerr
		}
	}
	if flerr := escritor.Flush(); flerr != nil {
		tmp.Close()
		return "", flerr
	}
	// Sincronizar antes del rename: sin esto, un corte de energía podía dejar
	// un archivo con el nombre final pero con datos sin bajar a disco.
	if serr := tmp.Sync(); serr != nil {
		tmp.Close()
		return "", serr
	}
	tmp.Close()

	if err := os.Rename(tmpPath, dest); err != nil {
		// Cross-device rename fallback.
		if in, inErr := os.Open(tmpPath); inErr == nil {
			out, outErr := os.Create(dest)
			if outErr == nil {
				_, _ = io.Copy(out, in)
				out.Close()
				in.Close()
				os.Remove(tmpPath)
			} else {
				in.Close()
				return "", outErr
			}
		} else {
			return "", inErr
		}
	}

	_ = title
	_ = artist
	return dest, nil
}
