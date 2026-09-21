package gobackend

import (
	"encoding/json"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"testing"
	"time"
)

// Prueba de RED (no corre en CI): BITLY_COVER_RED=1 go test ./internal/gobackend/ -run TestSaveCoverRed -v
//
// Verifica contra carátulas reales que SaveCover baja el archivo, que
// GetCoverPathForTrack lo recupera por URL y que un cover muerto (404) no
// deja basura ni un archivo vacío en disco.
func TestSaveCoverRed(t *testing.T) {
	if os.Getenv("BITLY_COVER_RED") != "1" {
		t.Skip("set BITLY_COVER_RED=1 para correr la prueba de red")
	}
	url := os.Getenv("BITLY_COVER_URL")
	if url == "" {
		url = coverVivaDePrueba(t)
	}
	if url == "" {
		t.Skip("sin URL de carátula para probar")
	}

	dir := t.TempDir()
	setDownloadDir(dir)
	defer setDownloadDir("")

	// 1) Primera bajada: archivo real en disco.
	payload, _ := json.Marshal(map[string]interface{}{
		"url":  url,
		"keys": []string{"RED-ISRC-1", "Tema de prueba|Artista"},
	})
	inicio := time.Now()
	ruta := SaveCover(string(payload))
	if ruta == "" {
		t.Fatalf("SaveCover devolvió vacío para %s", url)
	}
	info, err := os.Stat(ruta)
	if err != nil {
		t.Fatalf("la ruta devuelta no existe: %v", err)
	}
	if info.Size() == 0 {
		t.Fatalf("archivo de 0 bytes en %s", ruta)
	}
	if filepath.Dir(ruta) != filepath.Join(dir, ".covers") {
		t.Errorf("la portada no fue al dir de descargas: %s", ruta)
	}
	t.Logf("bajada: %s (%d bytes en %v)", filepath.Base(ruta), info.Size(), time.Since(inicio))

	// 2) Segunda llamada: la misma ruta, sin volver a bajar.
	if otra := SaveCover(string(payload)); otra != ruta {
		t.Errorf("la caché no se reusó: %s != %s", otra, ruta)
	}

	// 3) Recuperación por URL y por clave (like por un lado, descarga por otro).
	got := GetCoverPathForTrack(`{"cover_url":` + jsonQuote(url) + `}`)
	if got != ruta {
		t.Errorf("GetCoverPathForTrack no recuperó la portada por URL: %q != %q", got, ruta)
	}
	porIsrc := GetCoverPathForTrack(`{"isrc":"RED-ISRC-1"}`)
	if porIsrc != ruta {
		t.Errorf("GetCoverPathForTrack no recuperó la portada por ISRC: %q != %q", porIsrc, ruta)
	}

	// 4) URL muerta: vacío, sin archivo.
	muerta := "https://i.scdn.co/image/0000000000000000000000000000000000000000"
	if got := SaveCover(`{"url":` + jsonQuote(muerta) + `}`); got != "" {
		if _, err := os.Stat(got); err == nil {
			t.Errorf("se guardó un archivo para una URL muerta: %s", got)
		}
	}

	// 5) URL basura / payload inválido: nunca un archivo.
	for _, p := range []string{``, `{`, `{"url":""}`, `{"url":"no-es-url"}`} {
		if got := SaveCover(p); got != "" {
			t.Errorf("payload %q devolvió %q", p, got)
		}
	}
}

// coverVivaDePrueba pide a Deezer (sin auth) una carátula real y devuelve su
// URL, para que la prueba no dependa de una URL escrita a mano.
func coverVivaDePrueba(t *testing.T) string {
	client := &http.Client{Timeout: 20 * time.Second}
	resp, err := client.Get("https://api.deezer.com/search?q=bad%20bunny&limit=1")
	if err != nil {
		t.Logf("Deezer no respondió: %v", err)
		return ""
	}
	defer resp.Body.Close()
	var out struct {
		Data []struct {
			Cover string `json:"cover_xl"`
		} `json:"data"`
	}
	if err := json.NewDecoder(io.LimitReader(resp.Body, 1<<20)).Decode(&out); err != nil || len(out.Data) == 0 {
		return ""
	}
	return out.Data[0].Cover
}

func jsonQuote(s string) string {
	b, _ := json.Marshal(s)
	return string(b)
}
