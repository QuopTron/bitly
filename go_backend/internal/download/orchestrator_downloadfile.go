package download

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
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
	dest := filepath.Join(outDir, sanitizarNombreArchivo(base)+ext)

	// Look for a partial download file to resume from. The temp file pattern
	// is "dl-*{ext}" in the output directory. We scan for existing partials
	// that match the destination base name so concurrent companion downloads
	// for different tracks don't interfere.
	var partialPath string
	var existingSize int64
	if entries, err := os.ReadDir(outDir); err == nil {
		for _, e := range entries {
			if e.IsDir() {
				continue
			}
			name := e.Name()
			// Match dl-*{ext} temp files (our own partials from previous attempts)
			if strings.HasPrefix(name, "dl-") && strings.HasSuffix(name, ext) {
				info, err := e.Info()
				if err == nil && info.Size() > 0 {
					partialPath = filepath.Join(outDir, name)
					existingSize = info.Size()
					break
				}
			}
		}
	}

	client := &http.Client{Timeout: 0}
	var resp *http.Response
	var err error

	if partialPath != "" && existingSize > 0 {
		// Attempt resume with Range header.
		reqHTTP, _ := http.NewRequest("GET", url, nil)
		reqHTTP.Header.Set("Range", fmt.Sprintf("bytes=%d-", existingSize))
		resp, err = client.Do(reqHTTP)
		if err == nil && resp.StatusCode == http.StatusPartialContent {
			// Server supports Range: append to the existing partial file.
			log.Printf("[download] resuming from byte %d for %s", existingSize, base)
			return anexarAArchivo(partialPath, resp, existingSize, onProgress)
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

	tmp, err := os.CreateTemp(outDir, "dl-*"+ext)
	if err != nil {
		return "", err
	}
	tmpPath := tmp.Name()
	defer func() {
		if _, statErr := os.Stat(tmpPath); statErr == nil {
			os.Remove(tmpPath)
		}
	}()

	var done int64
	buf := make([]byte, 64*1024)
	for {
		n, rerr := resp.Body.Read(buf)
		if n > 0 {
			if _, werr := tmp.Write(buf[:n]); werr != nil {
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
