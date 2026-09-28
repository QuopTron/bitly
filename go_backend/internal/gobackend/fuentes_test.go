package gobackend

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// El id viaja desde Flutter y termina siendo un NOMBRE DE ARCHIVO: si no se
// valida, un id con "../" escribe fuera de la carpeta de tipografías. Este test
// fija ese borde.
func TestIdFuenteValido(t *testing.T) {
	validos := []string{"inter", "google_sans", "jetbrains_mono", "a", "space_grotesk_2"}
	for _, id := range validos {
		if !idFuenteValido(id) {
			t.Errorf("idFuenteValido(%q) = false, se esperaba true", id)
		}
	}
	invalidos := []string{
		"", "../escape", "a/b", "Mayusculas", "con guion", "con.punto",
		strings.Repeat("x", 33), "acentuadó",
	}
	for _, id := range invalidos {
		if idFuenteValido(id) {
			t.Errorf("idFuenteValido(%q) = true, se esperaba false", id)
		}
	}
}

// Un espejo caído o un portal cautivo contestan 200 con HTML. Guardarlo como
// .ttf dejaría la tipografía "elegida" pero invisible, que es peor que un
// error porque no se distingue de que funcionó.
func TestFirmaFuente(t *testing.T) {
	cabecera := func(b ...byte) []byte {
		data := make([]byte, 16)
		copy(data, b)
		return data
	}
	truetype := cabecera(0x00, 0x01, 0x00, 0x00)
	if !firmaFuente(truetype) {
		t.Error("se esperaba TrueType 0x00010000 reconocido")
	}
	for _, tag := range []string{"true", "OTTO", "ttcf", "typ1"} {
		if !firmaFuente([]byte(tag + "xxxxxxxxxxxx")) {
			t.Errorf("se esperaba %q reconocido como tipografía", tag)
		}
	}
	rechazados := [][]byte{
		[]byte("<!DOCTYPE html><html>"),
		[]byte("<html><body>403"),
		[]byte(""),
		[]byte("\x00\x01\x00"),
	}
	for _, data := range rechazados {
		if firmaFuente(data) {
			t.Errorf("se esperaba %q rechazado", string(data))
		}
	}
}

func TestCoincideSHA256(t *testing.T) {
	// Vector conocido y estable — sha256("") — para no "verificar" la función
	// contra sí misma.
	const vacioSHA256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
	if !coincideSHA256(nil, "") {
		t.Error("sin huella declarada debería aceptar")
	}
	if !coincideSHA256(nil, vacioSHA256) {
		t.Error("con la huella correcta debería aceptar")
	}
	if !coincideSHA256(nil, strings.ToUpper(vacioSHA256)) {
		t.Error("la huella debería compararse sin distinguir mayúsculas")
	}
	if coincideSHA256([]byte("otra cosa"), vacioSHA256) {
		t.Error("con una huella que no corresponde debería rechazar")
	}
}

// FuentesDir cuelga del directorio de datos de la app; en los tests se apunta
// BITLY_EXT_DIR a un temporal para no escribir en el disco real.
func prepararDirFuentes(t *testing.T) string {
	t.Helper()
	tmp := t.TempDir()
	t.Setenv("BITLY_EXT_DIR", filepath.Join(tmp, "ext"))
	dir := FuentesDir()
	if err := os.MkdirAll(dir, 0755); err != nil {
		t.Fatalf("no se pudo crear %s: %v", dir, err)
	}
	return dir
}

func TestDescargarFuenteRechazaIdInseguro(t *testing.T) {
	prepararDirFuentes(t)
	// Si el id no es válido NI SIQUIERA se mira la url: no hay red de por medio.
	if got := DescargarFuente(`{"id":"../escape","url":"https://ejemplo.com/a.ttf"}`); got != "" {
		t.Errorf("un id inseguro debería devolver vacío, devolvió %q", got)
	}
	if got := DescargarFuente(`no soy json`); got != "" {
		t.Errorf("un payload roto debería devolver vacío, devolvió %q", got)
	}
}

func TestDescargarFuenteSinUrlNiCacheDevuelveVacio(t *testing.T) {
	prepararDirFuentes(t)
	if got := DescargarFuente(`{"id":"inter","url":""}`); got != "" {
		t.Errorf("sin url y sin caché debería devolver vacío, devolvió %q", got)
	}
}

// Con el archivo ya en disco NO se toca la red: se pasa una url imposible y el
// test sigue siendo determinista porque nunca se llega a pedirla.
func TestDescargarFuenteDevuelveLaCacheSinRed(t *testing.T) {
	dir := prepararDirFuentes(t)
	camino := filepath.Join(dir, "inter.ttf")
	if err := os.WriteFile(camino, []byte("true\x00\x00\x00\x00xxxxxxxx"), 0644); err != nil {
		t.Fatal(err)
	}
	got := DescargarFuente(`{"id":"inter","url":"http://127.0.0.1:1/nunca-responde"}`)
	if got == "" {
		t.Fatal("con la tipografía ya en disco debería devolver su ruta")
	}
	want, _ := filepath.Abs(camino)
	if got != want {
		t.Errorf("ruta = %q, se esperaba %q", got, want)
	}
}

// Un archivo truncado (descarga cortada a la mitad) no puede quedar como si
// sirviera: se descarta al detectarlo.
func TestDescargarFuenteDescartaArchivoRoto(t *testing.T) {
	dir := prepararDirFuentes(t)
	camino := filepath.Join(dir, "manrope.ttf")
	if err := os.WriteFile(camino, []byte("<html>error del espejo</html>"), 0644); err != nil {
		t.Fatal(err)
	}
	if got := DescargarFuente(`{"id":"manrope","url":""}`); got != "" {
		t.Errorf("con el archivo roto y sin url debería devolver vacío, devolvió %q", got)
	}
	if _, err := os.Stat(camino); !os.IsNotExist(err) {
		t.Error("el archivo roto debería haberse borrado")
	}
}

func TestBorrarFuentes(t *testing.T) {
	dir := prepararDirFuentes(t)
	if err := os.WriteFile(filepath.Join(dir, "inter.ttf"), []byte("true\x00\x00\x00\x00xxxxxxxx"), 0644); err != nil {
		t.Fatal(err)
	}
	if got := BorrarFuentes(); got != `{"ok":true}` {
		t.Errorf("BorrarFuentes() = %q", got)
	}
	if _, err := os.Stat(dir); !os.IsNotExist(err) {
		t.Error("la carpeta de tipografías debería haberse borrado")
	}
}
