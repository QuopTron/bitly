package streaming

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"
)

// StartServer starts an HTTP server on the given port that proxies audio streams.
// Only for desktop use. Returns the server address.
func (s *Streamer) StartServer(port int) (string, error) {
	mux := http.NewServeMux()
	mux.HandleFunc("/stream", func(w http.ResponseWriter, r *http.Request) {
		audioURL := r.URL.Query().Get("url")
		if audioURL == "" {
			http.Error(w, "missing url", http.StatusBadRequest)
			return
		}
		if err := s.StreamURL(w, r, audioURL); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
		}
	})
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"status":"ok"}`))
	})

	addr := fmt.Sprintf(":%d", port)
	s.server = &http.Server{
		Addr:    addr,
		Handler: mux,
	}

	go func() {
		s.server.ListenAndServe()
	}()

	return fmt.Sprintf("http://localhost%s", addr), nil
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
