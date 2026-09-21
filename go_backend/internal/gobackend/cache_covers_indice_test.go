package gobackend

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
)

// limpiaIndicePortadas olvida la caché en memoria del índice (los tests usan
// directorios temporales distintos y no deben arrastrar estado entre casos).
func limpiaIndicePortadas() {
	muIndicePortadas.Lock()
	indicePortadas = map[string]map[string]string{}
	muIndicePortadas.Unlock()
}

func TestIndicePortadaRegistraYRecupera(t *testing.T) {
	limpiaIndicePortadas()
	dir := t.TempDir()
	nombre := "abc123.jpg"
	if err := os.WriteFile(filepath.Join(dir, nombre), []byte("x"), 0644); err != nil {
		t.Fatal(err)
	}
	registrarClavesPortada(dir, []string{"USUM71703861", "track1", "Moscow Mule|Bad Bunny"}, nombre)

	for _, clave := range []string{"USUM71703861", "track1", "Moscow Mule|Bad Bunny"} {
		if got := buscarClavePortada(dir, clave); got != nombre {
			t.Errorf("clave %q: se esperaba %q, llegó %q", clave, nombre, got)
		}
	}
	// El nombre puede llegar con otra capitalización desde otra fuente.
	if got := buscarClavePortada(dir, "moscow mule|bad bunny"); got != nombre {
		t.Errorf("la clave en minúsculas no se recuperó: %q", got)
	}
	// Y una clave que nunca se registró no inventa nada.
	if got := buscarClavePortada(dir, "otra cosa"); got != "" {
		t.Errorf("clave desconocida devolvió %q", got)
	}
}

func TestIndicePortadaSobreviveAlReinicio(t *testing.T) {
	limpiaIndicePortadas()
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "f.jpg"), []byte("x"), 0644); err != nil {
		t.Fatal(err)
	}
	registrarClavesPortada(dir, []string{"ISRC123"}, "f.jpg")

	// Simula el reinicio del proceso: se pierde el mapa en memoria.
	limpiaIndicePortadas()
	if got := buscarClavePortada(dir, "ISRC123"); got != "f.jpg" {
		t.Errorf("el índice no se releyó del disco: %q", got)
	}
}

func TestIndicePortadaOlvidaArchivoEvictado(t *testing.T) {
	limpiaIndicePortadas()
	dir := t.TempDir()
	if err := os.WriteFile(filepath.Join(dir, "f.jpg"), []byte("x"), 0644); err != nil {
		t.Fatal(err)
	}
	registrarClavesPortada(dir, []string{"ISRC1", "nombre"}, "f.jpg")
	os.Remove(filepath.Join(dir, "f.jpg"))

	// Clave muerta: no devuelve nada y se limpia sola.
	if got := buscarClavePortada(dir, "ISRC1"); got != "" {
		t.Errorf("una carátula borrada no puede seguir apuntando a nada: %q", got)
	}
	if got := buscarClavePortada(dir, "nombre"); got != "" {
		t.Errorf("quedó una clave huérfana: %q", got)
	}
	if idx := indiceDePortadas(dir); len(idx) != 0 {
		t.Errorf("el índice debía quedar vacío, tiene %d claves", len(idx))
	}
}

func TestIndicePortadaIgnoraClavesBasura(t *testing.T) {
	limpiaIndicePortadas()
	dir := t.TempDir()
	registrarClavesPortada(dir, []string{"", " ", "a"}, "f.jpg")
	if idx := indiceDePortadas(dir); len(idx) != 0 {
		t.Errorf("se indexaron claves inválidas: %v", idx)
	}
}

func TestGetCoverPathForTrackRecuperaPorClave(t *testing.T) {
	limpiaIndicePortadas()
	dir := t.TempDir()
	setDownloadDir(dir)
	defer setDownloadDir("")

	// Una portada guardada por un LIKE (por url) debe aparecer cuando la
	// DESCARGA la busca por ISRC.
	nombre := "portada.jpg"
	ruta := filepath.Join(dir, ".covers", nombre)
	if err := os.MkdirAll(filepath.Dir(ruta), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(ruta, []byte("x"), 0644); err != nil {
		t.Fatal(err)
	}
	registrarClavesPortada(filepath.Dir(ruta), []string{"USUM71703861"}, nombre)

	payload, _ := json.Marshal(map[string]string{"isrc": "USUM71703861"})
	got := GetCoverPathForTrack(string(payload))
	want, _ := filepath.Abs(ruta)
	if got != want {
		t.Errorf("no se recuperó la portada por ISRC: %q != %q", got, want)
	}
}

func TestSaveCoverRechazaLoQueNoEsImagen(t *testing.T) {
	limpiaIndicePortadas()
	dir := t.TempDir()
	setDownloadDir(dir)
	defer setDownloadDir("")

	// Un 200 con HTML (portal cautivo, WAF o error del CDN) no es una portada.
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		w.Write([]byte("<html>error</html>"))
	}))
	defer srv.Close()

	if got := SaveCover(`{"url":"` + srv.URL + `/x.jpg"}`); got != "" {
		t.Errorf("se aceptó HTML como carátula: %q", got)
	}
	// Y tampoco dejó un archivo basura en disco.
	if entries, _ := os.ReadDir(filepath.Join(dir, ".covers")); len(entries) != 0 {
		t.Errorf("quedaron %d archivos tras un rechazo", len(entries))
	}
}

func TestSaveCoverGuardaImagenYMandaCabeceras(t *testing.T) {
	limpiaIndicePortadas()
	dir := t.TempDir()
	setDownloadDir(dir)
	defer setDownloadDir("")

	jpeg := append([]byte{0xFF, 0xD8, 0xFF}, make([]byte, 32)...)
	vistas := map[string]string{}
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		vistas["ua"] = r.Header.Get("User-Agent")
		w.Write(jpeg)
	}))
	defer srv.Close()

	payload, _ := json.Marshal(map[string]interface{}{
		"url":  srv.URL + "/c.jpg",
		"keys": []string{"ISRC9", "Tema|Artista"},
	})
	got := SaveCover(string(payload))
	if got == "" {
		t.Fatal("SaveCover no guardó una imagen válida")
	}
	if vistas["ua"] == "" {
		t.Error("se bajó la portada sin User-Agent")
	}
	// Las claves quedaron indexadas para otros caminos.
	buscar := func(isrc string) string {
		b, _ := json.Marshal(map[string]string{"isrc": isrc})
		return GetCoverPathForTrack(string(b))
	}
	if buscar("ISRC9") == "" {
		t.Error("la clave ISRC no quedó indexada")
	}
	// El nombre compuesto también queda indexado (misma portada, otra clave).
	if buscar("Tema|Artista") == "" {
		t.Error("la clave de nombre no quedó indexada")
	}
}
