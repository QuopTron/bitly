package download

import (
	"os"
	"path/filepath"
	"testing"
)

// La garantía que se pidió, probada donde se aplica: un binario renombrado a
// .flac NO entra por NINGUNA ruta de descarga. Internet Archive y Soulseek
// comparten este filtro, así que la prueba vale para las dos fuentes.
//
// El nombre del archivo dice ".flac" a propósito: es exactamente el engaño que
// el filtro tiene que ver a través (la extensión no prueba nada; los bytes sí).
func TestBinarioRenombradoNoPasaLaValidacion(t *testing.T) {
	casos := []struct {
		descripcion string
		cabeza      []byte
	}{
		{"un ejecutable de Windows (.exe)", []byte{'M', 'Z', 0x90, 0x00, 0x03, 0x00, 0x00, 0x00}},
		{"un binario de Linux (ELF)", []byte{0x7F, 'E', 'L', 'F', 0x02, 0x01, 0x01, 0x00}},
		{"un binario de macOS (Mach-O)", []byte{0xCF, 0xFA, 0xED, 0xFE, 0x07, 0x00, 0x00, 0x01}},
		{"un script con shebang", []byte("#!/bin/sh\nrm -rf ~\n")},
		{"un ZIP/APK/JAR", []byte{'P', 'K', 0x03, 0x04, 0x14, 0x00, 0x00, 0x00}},
		{"un GZIP", []byte{0x1F, 0x8B, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00}},
		{"un PDF", []byte("%PDF-1.7\n1 0 obj\n")},
		{"una página web", []byte("<!DOCTYPE html><html><body>")},
		{"una base SQLite", []byte("SQLite format 3\x00")},
	}
	for _, c := range casos {
		dir := t.TempDir()
		path := filepath.Join(dir, "pista.flac")
		cuerpo := append(append([]byte{}, c.cabeza...), make([]byte, 4096)...)
		if err := os.WriteFile(path, cuerpo, 0o600); err != nil {
			t.Fatal(err)
		}
		if esArchivoAudioReproducible(path) {
			t.Fatalf("%s pasó la validación solo por llamarse .flac", c.descripcion)
		}
	}
}

// Y el otro lado del filtro, que importa igual: el audio real PASA. Si fuera
// demasiado estricto, no sonaría nada y el "arreglo" sería peor que el problema.
func TestAudioRealPasaLaValidacion(t *testing.T) {
	casos := map[string][]byte{
		"flac": []byte("fLaC"),
		"mp3":  []byte{'I', 'D', '3', 0x03, 0x00, 0x00, 0x00},
		"ogg":  []byte("OggS"),
		"opus": []byte("OggS"),
		"m4a":  {0x00, 0x00, 0x00, 0x20, 'f', 't', 'y', 'p'},
		// RIFF necesita su marca de formato en el offset 8: "RIFF" solo
		// también lo lleva un AVI o un WebP, y esos no son audio.
		"wav": []byte("RIFF\x00\x00\x00\x00WAVE"),
	}
	for ext, cabeza := range casos {
		dir := t.TempDir()
		path := filepath.Join(dir, "pista."+ext)
		cuerpo := append(append([]byte{}, cabeza...), make([]byte, 4096)...)
		if err := os.WriteFile(path, cuerpo, 0o600); err != nil {
			t.Fatal(err)
		}
		if !esArchivoAudioReproducible(path) {
			t.Fatalf("un %s válido no pasó la validación", ext)
		}
	}
}

// Un archivo diminuto (o vacío) no es "audio vacío": es una descarga fallida.
// La cabecera de 4 bytes de un FLAC sola no alcanza para reproducir nada.
func TestArchivoDiminutoNoPasaLaValidacion(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "pista.flac")
	if err := os.WriteFile(path, []byte("fLaC"), 0o600); err != nil {
		t.Fatal(err)
	}
	if esArchivoAudioReproducible(path) {
		t.Fatal("un archivo de 4 bytes pasó como audio reproducible")
	}
}
