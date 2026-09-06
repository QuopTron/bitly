package streaming

import (
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"github.com/zarz/bitly/go_backend/internal/httpclient"
)

// Streamer handles audio streaming over HTTP with range support.
type Streamer struct {
	client  *http.Client
	cache   *Cache
	server  *http.Server
}

// NewStreamer creates an audio streamer.
func NewStreamer() *Streamer {
	return &Streamer{
		client: &http.Client{Timeout: 30 * time.Second},
		cache:  NewCache(),
	}
}

// streamChunkSize caps each upstream range request. YouTube bot-gates some
// egress IPs: whole-file, open-ended, or large (>1MB) Range requests get 403
// while small bounded ranges (a real client's chunk requests) serve fine.
// mpv asks for the whole file in one request, so the proxy fetches upstream in
// bounded chunks and pipes them through.
const streamChunkSize = 512 * 1024

// youtubeMediaUA matches the ANDROID_VR client the resolved googlevideo URLs
// are minted for (c=ANDROID_VR). Accepted on small bounded ranges regardless of
// UA, but sending the client's own UA is the closest to a real device.
const youtubeMediaUA = "com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip"

// StreamURL proxies an audio URL with Range support, fetching the upstream in
// small bounded chunks (see streamChunkSize) and piping them to the caller
// (mpv). Used for desktop and, since googlevideo URLs are bot-gated on some
// networks, for Android playback through the in-process Go server.
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
	// the first upstream chunk probe below can override/complete them.
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
	// fetchChunk requests one bounded upstream range, retrying transient
	// failures (network hiccups, momentary bot-gate 403s) a couple of times
	// before giving up. Without this, a single failed mid-stream chunk closes
	// the client connection and truncates the song at the last good chunk
	// boundary (e.g. exactly 512KB in) — mpv then "completes" early and the
	// app thinks the stream died.
	fetchChunk := func(from int64) (*http.Response, error) {
		var lastErr error
		for attempt := 0; attempt < 3; attempt++ {
			if attempt > 0 {
				time.Sleep(time.Duration(attempt) * 300 * time.Millisecond)
			}
			req, err := http.NewRequest("GET", audioURL, nil)
			if err != nil {
				return nil, err
			}
			req.Header.Set("Range", fmt.Sprintf("bytes=%d-%d", from, from+streamChunkSize-1))
			req.Header.Set("User-Agent", youtubeMediaUA)
			resp, err := s.client.Do(req)
			if err != nil {
				lastErr = err
				continue
			}
			if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusPartialContent {
				body := make([]byte, 64)
				resp.Body.Read(body)
				resp.Body.Close()
				lastErr = fmt.Errorf("upstream %s returned %d (%.64s)", audioURL, resp.StatusCode, string(body))
				continue
			}
			return resp, nil
		}
		return nil, lastErr
	}
	pos := start
	resp, err := fetchChunk(pos)
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
	// after ~20s). The true total lives in the Content-Range header
	// ("bytes 0-524287/4048892" — after the last '/').
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
		resp, err = fetchChunk(pos)
		if err != nil {
			return err
		}
	}
	return nil
}

// StreamChunk fetches a byte range of audio for mobile/AAR use.
func (s *Streamer) StreamChunk(audioURL string, offset, length int64) ([]byte, error) {
	req, err := http.NewRequest("GET", audioURL, nil)
	if err != nil {
		return nil, err
	}
	if offset >= 0 && length > 0 {
		req.Header.Set("Range", fmt.Sprintf("bytes=%d-%d", offset, offset+length-1))
	}
	req.Header.Set("User-Agent", httpclient.RandomUserAgent())

	resp, err := s.client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusPartialContent {
		return nil, fmt.Errorf("stream: %s returned %d", audioURL, resp.StatusCode)
	}

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, err
	}

	if offset >= 0 {
		idx := int(offset / int64(chunkSize))
		s.cache.Add(audioURL, Chunk{Data: data, Index: idx, Size: len(data), IsLast: len(data) < int(length)})
	}

	return data, nil
}
