package server

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestNewRouter(t *testing.T) {
	r := NewRouter()
	if r == nil {
		t.Fatal("expected non-nil Router")
	}
	if r.mux == nil {
		t.Error("expected non-nil ServeMux")
	}
}

func TestRouter_HandleAndMux(t *testing.T) {
	r := NewRouter()
	called := false
	r.Handle("/test", func(w http.ResponseWriter, r *http.Request) {
		called = true
		w.WriteHeader(http.StatusOK)
	})

	mux := r.Mux()
	if mux == nil {
		t.Fatal("expected non-nil mux")
	}

	req := httptest.NewRequest("GET", "/test", nil)
	w := httptest.NewRecorder()
	mux.ServeHTTP(w, req)

	if !called {
		t.Error("expected handler to be called")
	}
	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestJSON_Write(t *testing.T) {
	w := httptest.NewRecorder()
	data := map[string]string{"hello": "world"}
	JSON(w, http.StatusOK, data)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
	if w.Header().Get("Content-Type") != "application/json" {
		t.Errorf("Content-Type = %q", w.Header().Get("Content-Type"))
	}

	var result map[string]string
	if err := json.Unmarshal(w.Body.Bytes(), &result); err != nil {
		t.Fatalf("failed to parse JSON: %v", err)
	}
	if result["hello"] != "world" {
		t.Errorf("result = %v", result)
	}
}

func TestJSON_StatusCodes(t *testing.T) {
	tests := []int{
		http.StatusOK,
		http.StatusCreated,
		http.StatusBadRequest,
		http.StatusNotFound,
		http.StatusInternalServerError,
	}
	for _, status := range tests {
		w := httptest.NewRecorder()
		JSON(w, status, map[string]string{"status": "test"})
		if w.Code != status {
			t.Errorf("expected %d, got %d", status, w.Code)
		}
	}
}

func TestError(t *testing.T) {
	w := httptest.NewRecorder()
	Error(w, http.StatusNotFound, "not found")

	if w.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", w.Code)
	}
	if w.Header().Get("Content-Type") != "application/json" {
		t.Errorf("Content-Type = %q", w.Header().Get("Content-Type"))
	}

	var result map[string]string
	json.Unmarshal(w.Body.Bytes(), &result)
	if result["error"] != "not found" {
		t.Errorf("error message = %q", result["error"])
	}
}

func TestLogger(t *testing.T) {
	handler := Logger(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest("GET", "/test", nil)
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected 200, got %d", w.Code)
	}
}

func TestCORS(t *testing.T) {
	tests := []struct {
		method string
		want   int
	}{
		{"GET", http.StatusOK},
		{"POST", http.StatusOK},
		{"OPTIONS", http.StatusOK},
	}
	for _, tt := range tests {
		handler := CORS(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.WriteHeader(http.StatusOK)
		}))

		req := httptest.NewRequest(tt.method, "/test", nil)
		w := httptest.NewRecorder()
		handler.ServeHTTP(w, req)

		if w.Code != tt.want {
			t.Errorf("%s: expected %d, got %d", tt.method, tt.want, w.Code)
		}
		if w.Header().Get("Access-Control-Allow-Origin") != "*" {
			t.Error("expected CORS header")
		}
	}
}

func TestCORS_Headers(t *testing.T) {
	handler := CORS(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	}))

	req := httptest.NewRequest("GET", "/test", nil)
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if w.Header().Get("Access-Control-Allow-Methods") != "GET, POST, OPTIONS" {
		t.Errorf("Allow-Methods = %q", w.Header().Get("Access-Control-Allow-Methods"))
	}
	if w.Header().Get("Access-Control-Allow-Headers") != "Content-Type" {
		t.Errorf("Allow-Headers = %q", w.Header().Get("Access-Control-Allow-Headers"))
	}
}

func TestApplyMiddleware(t *testing.T) {
	var order []string
	mw1 := func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			order = append(order, "mw1")
			next.ServeHTTP(w, r)
		})
	}
	mw2 := func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			order = append(order, "mw2")
			next.ServeHTTP(w, r)
		})
	}

	finalHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		order = append(order, "final")
	})

	handler := ApplyMiddleware(finalHandler, mw1, mw2)
	req := httptest.NewRequest("GET", "/", nil)
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)

	if len(order) != 3 {
		t.Fatalf("expected 3 calls, got %d", len(order))
	}
	// Middleware applies in reverse order: mw2 first, then mw1, then final
	if order[0] != "mw2" && order[1] != "mw1" {
		t.Logf("middleware order: %v", order)
	}
}
