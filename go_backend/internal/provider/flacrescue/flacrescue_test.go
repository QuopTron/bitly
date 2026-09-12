// flacrescue_test.go — Pruebas del provider de rescate de audio.
//
// Verifica el contrato que sostiene todo el rescate "sin zarz":
//   - los espejos se leen de configuración (comas o JSON),
//   - se envían las cabeceras Origin/Referer que exigen los espejos,
//   - un espejo caído NO bloquea: se pasa al siguiente,
//   - la cascada degrada FLAC → MP3 en vez de fallar,
//   - el error del espejo se propaga legible (no un "no se pudo").
//
// Se conecta con: client.go y resolucion.go.
// Parte del flujo: red de seguridad del rescate de audio por ISRC.
package flacrescue

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

// TestSettingsParseanEspejosYOrigen comprueba la normalización de ajustes.
func TestSettingsParseanEspejosYOrigen(t *testing.T) {
	c := NewClient()

	c.SetSettings(map[string]string{
		"mirrors": "https://a.example, https://b.example/\nhttps://c.example",
		"origin":  "https://otro-origen.test/",
		"format":  "mp3_320",
	})
	espejos := c.Mirrors()
	if len(espejos) != 3 {
		t.Fatalf("esperaba 3 espejos, obtuve %d: %v", len(espejos), espejos)
	}
	if espejos[1] != "https://b.example" {
		t.Errorf("la barra final no se limpió: %q", espejos[1])
	}
	if c.origin != "https://otro-origen.test" {
		t.Errorf("origin = %q", c.origin)
	}
	if c.formato != "MP3_320" {
		t.Errorf("formato = %q", c.formato)
	}

	// También acepta array JSON.
	c.SetSettings(map[string]string{"mirrors": `["https://x.example","https://y.example"]`})
	if len(c.Mirrors()) != 2 {
		t.Errorf("no parseó el array JSON: %v", c.Mirrors())
	}

	// Un valor basura NO debe romper la lista actual.
	c.SetSettings(map[string]string{"mirrors": "no-es-una-url"})
	if len(c.Mirrors()) != 2 {
		t.Errorf("un ajuste inválido pisó los espejos: %v", c.Mirrors())
	}
}

// TestCascadaDegradaAP300 verifica el "flac a mp3": si el espejo ya no
// tiene FLAC, el rescate entrega MP3_320 en vez de fallar.
func TestCascadaDegradaAP300(t *testing.T) {
	var formatosPedidos []string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		formato := r.URL.Query().Get("format")
		formatosPedidos = append(formatosPedidos, formato)
		if formato != "MP3_320" {
			w.WriteHeader(http.StatusServiceUnavailable)
			_, _ = w.Write([]byte(`{"error":"no hay FLAC"}`))
			return
		}
		w.Header().Set("Content-Type", "audio/mpeg")
		_, _ = w.Write([]byte("audio"))
	}))
	defer srv.Close()

	c := NewClient()
	c.SetSettings(map[string]string{"mirrors": srv.URL, "format": "FLAC"})

	url, err := c.GetStreamURL("GBDUW0000053", "")
	if err != nil {
		t.Fatalf("el rescate debió degradar a MP3, error: %v", err)
	}
	if !strings.Contains(url, "format=MP3_320") {
		t.Errorf("URL inesperada: %s", url)
	}
	if len(formatosPedidos) < 2 || formatosPedidos[0] != "FLAC" {
		t.Errorf("se esperaba intentar FLAC primero: %v", formatosPedidos)
	}
}

// TestEnviaOriginYReferer: sin esas cabeceras los espejos dan 403.
func TestEnviaOriginYReferer(t *testing.T) {
	var origin, referer string
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		origin = r.Header.Get("Origin")
		referer = r.Header.Get("Referer")
		w.Header().Set("Content-Type", "audio/flac")
		_, _ = w.Write([]byte("fLaC"))
	}))
	defer srv.Close()

	c := NewClient()
	c.SetSettings(map[string]string{"mirrors": srv.URL})
	if _, err := c.GetStreamURL("GBDUW0000053", "flac"); err != nil {
		t.Fatalf("no debía fallar: %v", err)
	}
	if origin != defaultOrigin {
		t.Errorf("Origin = %q, esperaba %q", origin, defaultOrigin)
	}
	if referer != defaultOrigin+"/" {
		t.Errorf("Referer = %q", referer)
	}
}

// TestEspejoCaidoNoBloquea: el primero falla y el segundo responde.
func TestEspejoCaidoNoBloquea(t *testing.T) {
	caido := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusBadGateway)
	}))
	defer caido.Close()

	vivo := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{"url": "https://cdn.example/audio.flac"})
	}))
	defer vivo.Close()

	c := NewClient()
	c.SetSettings(map[string]string{"mirrors": caido.URL + "," + vivo.URL})

	url, err := c.GetStreamURL("GBDUW0000053", "flac")
	if err != nil {
		t.Fatalf("debía usar el segundo espejo: %v", err)
	}
	if url != "https://cdn.example/audio.flac" {
		t.Errorf("url = %q", url)
	}
}

// TestErrorDelEspejoEsLegible: cuando TODOS fallan (el caso real
// "All Deezer accounts are dead"), el error lo dice.
func TestErrorDelEspejoEsLegible(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusServiceUnavailable)
		_, _ = w.Write([]byte(`{"error":"All Deezer accounts are dead (banned/expired ARLs)"}`))
	}))
	defer srv.Close()

	c := NewClient()
	c.SetSettings(map[string]string{"mirrors": srv.URL, "format": "MP3_128"})

	_, err := c.GetStreamURL("GBDUW0000053", "128")
	if err == nil {
		t.Fatal("debía fallar")
	}
	if !strings.Contains(err.Error(), "All Deezer accounts are dead") {
		t.Errorf("el error no explica la causa real: %v", err)
	}
}

// TestSinCatalogoPropio deja claro que no compite como fuente de metadata.
func TestSinCatalogoPropio(t *testing.T) {
	c := NewClient()
	if _, err := c.SearchTracks("daft punk", 5); err == nil {
		t.Error("SearchTracks no debería funcionar")
	}
	if _, err := c.GetStreamURL("", "flac"); err == nil {
		t.Error("sin ISRC debería fallar")
	}
}
