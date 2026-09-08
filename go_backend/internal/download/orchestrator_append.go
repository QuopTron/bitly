package download

import (
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

// appendToFile resumes writing to an existing partial file [path] from a
// 206 Partial Content response. The HTTP response body is appended after
// [existingSize] bytes, progress is reported via [onProgress], and the
// destination file is atomically renamed when complete.
func anexarAArchivo(path string, resp *http.Response, existingSize int64, onProgress func(done, total int64)) (string, error) {
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
	f.Close()

	// Atomic rename: the partial "dl-*" file becomes the final destination.
	// Extract the base name from the partial filename to build the dest path.
	dir := filepath.Dir(path)
	// La ruta destino es la misma que downloadToFile produciria — usar el
	// directorio padre + el nombre base del parcial sin el prefijo "dl-".
	base := strings.TrimPrefix(filepath.Base(path), "dl-")
	// base starts with "-" (e.g. "-abc123.flac"), strip the leading dash.
	base = strings.TrimPrefix(base, "-")
	dest := filepath.Join(dir, base)
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
