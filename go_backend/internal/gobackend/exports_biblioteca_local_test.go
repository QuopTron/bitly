package gobackend

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/zarz/bitly/go_backend/internal/download"
)

// ═══════════════════════════════════════════════════════════════════════
// Importación local + dedupe por ISRC, desde el puente
//
// Crea un MP3 real con ID3v2 (TSRC = ISRC), lo importa y comprueba que el
// puente lo reconoce: resumen de importación, "qué me falta" y que la
// descarga de una canción ya importada NO baja nada.
// ═══════════════════════════════════════════════════════════════════════

func frameID3Test(id, valor string) []byte {
	datos := append([]byte{0x03}, []byte(valor)...)
	salida := make([]byte, 0, 10+len(datos))
	salida = append(salida, []byte(id)...)
	n := len(datos)
	salida = append(salida, byte(n>>24), byte(n>>16), byte(n>>8), byte(n))
	salida = append(salida, 0x00, 0x00)
	return append(salida, datos...)
}

func escribirMP3Test(t *testing.T, ruta, isrc, titulo, artista string) {
	t.Helper()
	var cuerpo []byte
	cuerpo = append(cuerpo, frameID3Test("TSRC", isrc)...)
	cuerpo = append(cuerpo, frameID3Test("TIT2", titulo)...)
	cuerpo = append(cuerpo, frameID3Test("TPE1", artista)...)
	n := len(cuerpo)
	cabecera := []byte{
		'I', 'D', '3', 0x03, 0x00, 0x00,
		byte((n >> 21) & 0x7F), byte((n >> 14) & 0x7F), byte((n >> 7) & 0x7F), byte(n & 0x7F),
	}
	if err := os.WriteFile(ruta, append(cabecera, cuerpo...), 0o644); err != nil {
		t.Fatalf("no se pudo escribir %s: %v", ruta, err)
	}
}

func TestBibliotecaLocalImportYDedupeEnPuente(t *testing.T) {
	if estado := InitGlobalState(); estado == "" {
		t.Fatal("InitGlobalState no devolvió estado")
	}
	if indiceLocal == nil {
		t.Fatal("indiceLocal quedó nil tras InitGlobalState")
	}

	dir := t.TempDir()
	escribirMP3Test(t, filepath.Join(dir, "comprada.mp3"), "USRC17607839", "Comprada", "Artista A")
	escribirMP3Test(t, filepath.Join(dir, "match.mp3"), "GBAYE0601498", "Match", "Artista B")

	// 1) Importar: resume cuántos archivos, cuántos con ISRC y el total.
	var resumen map[string]interface{}
	if err := json.Unmarshal([]byte(ImportarBibliotecaLocal(dir)), &resumen); err != nil {
		t.Fatalf("resumen inválido: %v", err)
	}
	if resumen["archivos"].(float64) != 2 || resumen["conIsrc"].(float64) != 2 {
		t.Errorf("resumen = %v, quiero archivos=2 conIsrc=2", resumen)
	}

	// 2) Qué me falta: solo lo que NO está en local.
	var faltan []string
	if err := json.Unmarshal([]byte(FaltantesLocales(`["USRC17607839","ZZZZZZZZZZZZ"]`)), &faltan); err != nil {
		t.Fatalf("faltantes inválido: %v", err)
	}
	if len(faltan) != 1 || faltan[0] != "ZZZZZZZZZZZZ" {
		t.Errorf("FaltantesLocales = %v, quiero [ZZZZZZZZZZZZ]", faltan)
	}

	// 3) Ruta local.
	var ruta struct {
		FilePath string `json:"filePath"`
	}
	if err := json.Unmarshal([]byte(RutaLocalISRC("USRC17607839")), &ruta); err != nil {
		t.Fatalf("ruta inválida: %v", err)
	}
	if !strings.HasSuffix(ruta.FilePath, "comprada.mp3") {
		t.Errorf("RutaLocalISRC = %q, quiero que termine en comprada.mp3", ruta.FilePath)
	}

	// 4) El dedupe de la descarga: una canción ya importada se resuelve como
	//    local (sin red), y una que no está NO se marca como local.
	local, yaEsta := resultadoLocalSiExiste(download.Request{
		ItemID: "item-1", ISRC: "USRC17607839", Title: "Comprada",
	})
	if !yaEsta {
		t.Fatal("resultadoLocalSiExiste = false para un ISRC importado")
	}
	if !local.Local || local.Provider != "local" || !strings.HasSuffix(local.FilePath, "comprada.mp3") {
		t.Errorf("resultado local inesperado: %+v", local)
	}

	if _, yaEsta := resultadoLocalSiExiste(download.Request{
		ItemID: "item-2", ISRC: "ZZZZZZZZZZZZ",
	}); yaEsta {
		t.Error("un ISRC que no está en local no debe resolverse como local")
	}
	if _, yaEsta := resultadoLocalSiExiste(download.Request{ItemID: "item-3"}); yaEsta {
		t.Error("sin ISRC no debe haber dedupe (se descarga normal)")
	}
}
