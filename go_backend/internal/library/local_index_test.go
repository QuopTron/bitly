package library

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// ═══════════════════════════════════════════════════════════════════════
// Prueba de la importación local y el dedupe por ISRC
//
// Crea MP3 reales con ID3v2 (TSRC = ISRC) y comprueba el flujo completo:
// escaneo → completar ISRC → índice → "qué me falta" → ruta del archivo.
// ═══════════════════════════════════════════════════════════════════════

// frameID3v2 construye una etiqueta ID3v2.3 con un frame de texto.
func frameID3v2(id, valor string) []byte {
	datos := append([]byte{0x03}, []byte(valor)...) // 0x03 = UTF-8
	salida := make([]byte, 0, 10+len(datos))
	salida = append(salida, []byte(id)...)
	n := len(datos)
	salida = append(salida, byte(n>>24), byte(n>>16), byte(n>>8), byte(n))
	salida = append(salida, 0x00, 0x00)
	return append(salida, datos...)
}

// escribirMP3ConISRC deja en disco un MP3 mínimo con ISRC, título y artista.
func escribirMP3ConISRC(t *testing.T, ruta, isrc, titulo, artista string) {
	t.Helper()
	var cuerpo []byte
	cuerpo = append(cuerpo, frameID3v2("TSRC", isrc)...)
	cuerpo = append(cuerpo, frameID3v2("TIT2", titulo)...)
	cuerpo = append(cuerpo, frameID3v2("TPE1", artista)...)

	n := len(cuerpo)
	cabecera := []byte{
		'I', 'D', '3', 0x03, 0x00, 0x00,
		byte((n >> 21) & 0x7F), byte((n >> 14) & 0x7F), byte((n >> 7) & 0x7F), byte(n & 0x7F),
	}
	if err := os.WriteFile(ruta, append(cabecera, cuerpo...), 0o644); err != nil {
		t.Fatalf("no se pudo escribir %s: %v", ruta, err)
	}
}

func TestImportarBibliotecaLocalYDedupe(t *testing.T) {
	dir := t.TempDir()
	escribirMP3ConISRC(t, filepath.Join(dir, "uno.mp3"), "USRC17607839", "Uno", "Artista A")
	escribirMP3ConISRC(t, filepath.Join(dir, "dos.mp3"), "GBAYE0601498", "Dos", "Artista B")
	// Un archivo sin ISRC: no debe entrar al índice.
	if err := os.WriteFile(filepath.Join(dir, "sin-isrc.mp3"), []byte("ID3\x03\x00\x00\x00\x00\x00\x00"), 0o644); err != nil {
		t.Fatal(err)
	}

	indice := NuevoIndiceLocal()
	total, err := indice.IndexarDirectorio(dir)
	if err != nil {
		t.Fatalf("IndexarDirectorio: %v", err)
	}
	if total != 2 {
		t.Errorf("indexados = %d, quiero 2 (el archivo sin ISRC no cuenta)", total)
	}

	// El dedupe: solo lo que NO está debe devolverse.
	faltan := indice.Faltantes([]string{"USRC17607839", "ZZZZZZZZZZZZ", "GBAYE0601498", "USRC17607839"})
	if len(faltan) != 1 || faltan[0] != "ZZZZZZZZZZZZ" {
		t.Errorf("Faltantes = %v, quiero [ZZZZZZZZZZZZ] (sin duplicados)", faltan)
	}

	// La ruta real del archivo.
	ruta := indice.RutaLocal("USRC17607839")
	if !strings.HasSuffix(ruta, "uno.mp3") {
		t.Errorf("RutaLocal = %q, quiero que termine en uno.mp3", ruta)
	}
	if indice.RutaLocal("ZZZZZZZZZZZZ") != "" {
		t.Error("RutaLocal de un ISRC inexistente debería ser \"\"")
	}
}

func TestScanCompletaISRC(t *testing.T) {
	dir := t.TempDir()
	escribirMP3ConISRC(t, filepath.Join(dir, "tema.mp3"), "USRC17607839", "Tema", "Artista")

	// library.Scan usa internal/audio, que NO devuelve ISRC al leer.
	// completarISRC debe rellenarlo con el parser de internal/cache.
	entradas, err := New().Scan(dir)
	if err != nil {
		t.Fatalf("Scan: %v", err)
	}
	if len(entradas) != 1 {
		t.Fatalf("entradas = %d, quiero 1", len(entradas))
	}
	meta := entradas[0].Metadata
	if meta == nil {
		t.Fatal("la entrada quedó sin metadata")
	}
	if meta.ISRC != "USRC17607839" {
		t.Errorf("ISRC = %q, quiero USRC17607839", meta.ISRC)
	}
	if entradas[0].FilePath == "" {
		t.Error("la entrada debería traer su FilePath")
	}

	// Y al indexar esas entradas ya escaneadas, el dedupe las reconoce.
	indice := NuevoIndiceLocal()
	if n := indice.IndexarEntradas(entradas); n != 1 {
		t.Errorf("IndexarEntradas = %d, quiero 1", n)
	}
	if faltan := indice.Faltantes([]string{"USRC17607839"}); len(faltan) != 0 {
		t.Errorf("Faltantes = %v, quiero vacío (ya está en local)", faltan)
	}
}

func TestLimpiarIndiceLocal(t *testing.T) {
	dir := t.TempDir()
	escribirMP3ConISRC(t, filepath.Join(dir, "a.mp3"), "USRC17607839", "A", "X")

	indice := NuevoIndiceLocal()
	if _, err := indice.IndexarDirectorio(dir); err != nil {
		t.Fatal(err)
	}
	if indice.Cantidad() != 1 {
		t.Fatalf("Cantidad = %d, quiero 1", indice.Cantidad())
	}
	indice.Limpiar()
	if indice.Cantidad() != 0 {
		t.Errorf("tras Limpiar, Cantidad = %d, quiero 0", indice.Cantidad())
	}
}
