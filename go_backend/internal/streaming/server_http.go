package streaming

import (
	"fmt"
	"net"
	"net/http"
	"strconv"
	"strings"
)

// StartServer starts an HTTP server on loopback that proxies audio streams,
// using an ephemeral port so app restarts / multiple instances never collide
// (the port is read back from the bound listener and returned in the URL).
// Returns the server base URL, e.g. http://127.0.0.1:41237.
func (s *Streamer) StartServer(port int) (string, error) {
	mux := http.NewServeMux()
	mux.HandleFunc("/stream", func(w http.ResponseWriter, r *http.Request) {
		audioURL := r.URL.Query().Get("url")
		if audioURL == "" {
			http.Error(w, "missing url", http.StatusBadRequest)
			return
		}
		// StreamURL writes its status/headers as soon as the FIRST upstream
		// chunk succeeds; an error returned AFTER that must not trigger a
		// second WriteHeader here ("superfluous response.WriteHeader call")
		// — appending an error body to an already-started audio response is
		// what produced corrupt "EOF with no data" streams for mpv.
		wr := &headerGuard{ResponseWriter: w}
		if err := s.StreamURL(wr, r, audioURL); err != nil && !wr.wroteHeader {
			http.Error(w, err.Error(), http.StatusInternalServerError)
		}
	})
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"ok"}`))
	})

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return "", err
	}
	realPort := ln.Addr().(*net.TCPAddr).Port
	s.server = &http.Server{
		Addr:    ln.Addr().String(),
		Handler: mux,
	}

	go func() {
		_ = s.server.Serve(ln)
	}()

	return fmt.Sprintf("http://127.0.0.1:%d", realPort), nil
}

// headerGuard wraps a ResponseWriter and records whether the response already
// started, so the /stream handler can tell a pre-header failure (safe to answer
// with a real error status) from a mid-stream failure (headers + bytes already
// sent — the connection must just be dropped, never double-written).
type headerGuard struct {
	http.ResponseWriter
	wroteHeader bool
}

func (g *headerGuard) WriteHeader(code int) {
	if !g.wroteHeader {
		g.wroteHeader = true
		g.ResponseWriter.WriteHeader(code)
	}
}

func (g *headerGuard) Write(b []byte) (int, error) {
	g.wroteHeader = true
	return g.ResponseWriter.Write(b)
}

// StopServer stops the streaming HTTP server.
func (s *Streamer) StopServer() error {
	if s.server != nil {
		return s.server.Close()
	}
	return nil
}

// ParseRange parses a Range header into offset and length.
func ParseRange(rangeHeader string, fileSize int64) (offset, length int64, err error) {
	if rangeHeader == "" {
		return 0, fileSize, nil
	}
	if !strings.HasPrefix(rangeHeader, "bytes=") {
		return 0, 0, fmt.Errorf("invalid range")
	}
	rangeStr := strings.TrimPrefix(rangeHeader, "bytes=")
	parts := strings.Split(rangeStr, "-")
	if len(parts) != 2 {
		return 0, 0, fmt.Errorf("invalid range format")
	}

	start, err := strconv.ParseInt(parts[0], 10, 64)
	if err != nil {
		return 0, 0, err
	}

	var end int64
	if parts[1] != "" {
		end, err = strconv.ParseInt(parts[1], 10, 64)
		if err != nil {
			return 0, 0, err
		}
	} else {
		end = fileSize - 1
	}

	return start, end - start + 1, nil
}
