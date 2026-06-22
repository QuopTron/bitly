package streaming

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

func TestNewStreamer(t *testing.T) {
	s := NewStreamer("/music")
	if s == nil {
		t.Fatal("expected non-nil Streamer")
	}
}

func TestNewStreamer_EmptyDir(t *testing.T) {
	s := NewStreamer("")
	if s == nil {
		t.Fatal("expected non-nil Streamer")
	}
}

func TestServeAudio_FileNotFound(t *testing.T) {
	s := NewStreamer("/nonexistent")
	w := httptest.NewRecorder()
	r := httptest.NewRequest("GET", "/audio/test.flac", nil)

	s.ServeAudio(w, r, "test.flac")

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", w.Code)
	}
}

func TestServeAudio_ValidFile(t *testing.T) {
	dir := t.TempDir()
	audioPath := filepath.Join(dir, "test.flac")
	content := []byte("fake flac content")
	if err := os.WriteFile(audioPath, content, 0644); err != nil {
		t.Fatal(err)
	}

	s := NewStreamer(dir)
	w := httptest.NewRecorder()
	r := httptest.NewRequest("GET", "/audio/test.flac", nil)

	s.ServeAudio(w, r, "test.flac")

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
	if w.Body.String() != string(content) {
		t.Errorf("body = %q, want %q", w.Body.String(), string(content))
	}
	if w.Header().Get("Content-Type") != "audio/flac" {
		t.Errorf("Content-Type = %q", w.Header().Get("Content-Type"))
	}
	if w.Header().Get("Accept-Ranges") != "bytes" {
		t.Errorf("Accept-Ranges = %q", w.Header().Get("Accept-Ranges"))
	}
}

func TestServeAudio_WithRange(t *testing.T) {
	dir := t.TempDir()
	audioPath := filepath.Join(dir, "test.flac")
	content := []byte("0123456789")
	if err := os.WriteFile(audioPath, content, 0644); err != nil {
		t.Fatal(err)
	}

	s := NewStreamer(dir)
	w := httptest.NewRecorder()
	r := httptest.NewRequest("GET", "/audio/test.flac", nil)
	r.Header.Set("Range", "bytes=0-4")

	s.ServeAudio(w, r, "test.flac")

	if w.Code != http.StatusPartialContent {
		t.Errorf("expected 206, got %d", w.Code)
	}
	if w.Header().Get("Content-Range") != "bytes 0-4/10" {
		t.Errorf("Content-Range = %q", w.Header().Get("Content-Range"))
	}
	if w.Body.String() != "01234" {
		t.Errorf("body = %q, want %q", w.Body.String(), "01234")
	}
}

func TestServeAudio_InvalidRange(t *testing.T) {
	dir := t.TempDir()
	audioPath := filepath.Join(dir, "test.flac")
	os.WriteFile(audioPath, []byte("content"), 0644)

	s := NewStreamer(dir)
	w := httptest.NewRecorder()
	r := httptest.NewRequest("GET", "/audio/test.flac", nil)
	// Range where start > end => not satisfiable
	r.Header.Set("Range", "bytes=10-5")

	s.ServeAudio(w, r, "test.flac")

	if w.Code != http.StatusRequestedRangeNotSatisfiable {
		t.Errorf("expected 416, got %d", w.Code)
	}
}

func TestServeAudio_RangePastEnd(t *testing.T) {
	dir := t.TempDir()
	audioPath := filepath.Join(dir, "test.flac")
	os.WriteFile(audioPath, []byte("short"), 0644)

	s := NewStreamer(dir)
	w := httptest.NewRecorder()
	r := httptest.NewRequest("GET", "/audio/test.flac", nil)
	r.Header.Set("Range", "bytes=100-200")

	s.ServeAudio(w, r, "test.flac")

	if w.Code != http.StatusRequestedRangeNotSatisfiable {
		t.Errorf("expected 416, got %d", w.Code)
	}
}

func TestMimeForExt(t *testing.T) {
	tests := []struct {
		ext  string
		want string
	}{
		{".flac", "audio/flac"},
		{".mp3", "audio/mpeg"},
		{".m4a", "audio/mp4"},
		{".aac", "audio/mp4"},
		{".opus", "audio/opus"},
		{".ogg", "audio/ogg"},
		{".wav", "audio/wav"},
		{".wma", "audio/x-ms-wma"},
		{".unknown", "application/octet-stream"},
	}
	for _, tt := range tests {
		got := mimeForExt(tt.ext)
		if got != tt.want {
			t.Errorf("mimeForExt(%q) = %q, want %q", tt.ext, got, tt.want)
		}
	}
}

func TestServeAudio_DifferentFormats(t *testing.T) {
	dir := t.TempDir()
	tests := []struct {
		name     string
		ext      string
		wantType string
	}{
		{"mp3", ".mp3", "audio/mpeg"},
		{"m4a", ".m4a", "audio/mp4"},
		{"opus", ".opus", "audio/opus"},
		{"wav", ".wav", "audio/wav"},
	}
	for _, tt := range tests {
		audioPath := filepath.Join(dir, "test"+tt.ext)
		os.WriteFile(audioPath, []byte("audio"), 0644)

		s := NewStreamer(dir)
		w := httptest.NewRecorder()
		r := httptest.NewRequest("GET", "/audio/test"+tt.ext, nil)

		s.ServeAudio(w, r, "test"+tt.ext)

		if w.Code != http.StatusOK {
			t.Errorf("%s: expected 200, got %d", tt.name, w.Code)
		}
		if w.Header().Get("Content-Type") != tt.wantType {
			t.Errorf("%s: Content-Type = %q, want %q", tt.name, w.Header().Get("Content-Type"), tt.wantType)
		}
	}
}
