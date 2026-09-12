package download

import (
	"io"
	"net/http"
	"os"
)

// appendToFile resumes writing to an existing partial file [path] from a
// 206 Partial Content response. The HTTP response body is appended after
// [existingSize] bytes, progress is reported via [onProgress], and the file
// is atomically renamed to [dest] when complete.
//
// [dest] llega explícito a propósito. Antes se deducía del nombre del
// temporal ("dl-7283645.flac" → "7283645.flac"), y eso tenía dos efectos
// malos: el archivo descargado quedaba con un nombre aleatorio en vez del de
// la pista (el reproductor y StreamCacheFile no lo encontraban), y un
// temporal de la descarga paralela producía un destino absurdo.
func anexarAArchivo(dest, path string, resp *http.Response, existingSize int64, onProgress func(done, total int64)) (string, error) {
	defer resp.Body.Close()

	f, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		// Can't append — fall through to full download on next attempt.
		return "", err
	}

	var done int64
	buf := make([]byte, 64*1024)
	for {
		n, rerr := resp.Body.Read(buf)
		if n > 0 {
			if _, werr := f.Write(buf[:n]); werr != nil {
				f.Close()
				return "", werr
			}
			done += int64(n)
			// Content-Length in a 206 response is the size of THIS range,
			// not the total file. Total = existingSize + Content-Length.
			total := existingSize + resp.ContentLength
			onProgress(existingSize+done, total)
		}
		if rerr == io.EOF {
			break
		}
		if rerr != nil {
			f.Close()
			return "", rerr
		}
	}
	// Sincronizar antes del rename: sin esto un corte de energía podía dejar
	// el archivo con el nombre final y datos sin bajar a disco.
	if serr := f.Sync(); serr != nil {
		f.Close()
		return "", serr
	}
	f.Close()

	// Atomic rename del parcial al destino final.
	if err := os.Rename(path, dest); err != nil {
		// Cross-device rename fallback.
		if in, inErr := os.Open(path); inErr == nil {
			out, outErr := os.Create(dest)
			if outErr == nil {
				_, _ = io.Copy(out, in)
				out.Close()
				in.Close()
				os.Remove(path)
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
