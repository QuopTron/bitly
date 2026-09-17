package download

import (
	"bufio"
	"fmt"
	"io"
	"net/http"
	"os"
)

// descargarSecuencialBajandoCompleto baja el archivo de una sola pasada (sin
// tramos en paralelo) y lo deja en [dest] con un rename atómico.
//
// Por qué aparte: orchestrator_downloadfile.go se ocupa de DECIDIR el camino
// (paralelo, reanudación, o pasada única) y este archivo, de la pasada única.
func descargarSecuencialBajandoCompleto(client *http.Client, url, outDir, dest, pista, huella, ext string,
	onProgress func(done, total int64)) (string, error) {
	resp, err := client.Get(url)
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

	return dest, nil
}
