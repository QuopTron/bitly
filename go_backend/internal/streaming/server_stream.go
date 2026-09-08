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
	pos := start
	resp, err := s.fetchChunk(audioURL, pos)
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
	for {
		n, err := io.Copy(w, resp.Body)
		resp.Body.Close()
		if flusher != nil {
			flusher.Flush()
		}
		if err != nil {
			return err
		}
		pos += n
		// EOF (n < chunk) or a server that ignored Range and sent the whole
		// body (n > chunk): either way everything downstream was delivered.
		if n != streamChunkSize {
			break
		}
		resp, err = s.fetchChunk(audioURL, pos)
		if err != nil {
			return err
		}
	}
	return nil
}

// StreamChunk fetches a byte range of audio for mobile/AAR use.
