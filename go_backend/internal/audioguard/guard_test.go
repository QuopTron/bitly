// guard_test.go — el filtro que separa "canción" de "binario".
//
// Se prueban las dos direcciones: que TODO audio real pase (si rechaza un FLAC
// legítimo, la descarga de Soulseek no sirve para nada) y que ningún ejecutable
// ni contenedor genérico pase (si acepta un .exe, el filtro no existe).
package audioguard

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// escribir crea un archivo con esa cabecera y un relleno del tamaño pedido.
func escribir(t *testing.T, nombre string, cabecera []byte, tam int64) string {
	t.Helper()
	ruta := filepath.Join(t.TempDir(), nombre)
	contenido := make([]byte, tam)
	copy(contenido, cabecera)
	if err := os.WriteFile(ruta, contenido, 0o600); err != nil {
		t.Fatalf("no se pudo crear %s: %v", nombre, err)
	}
	return ruta
}

func TestAceptaAudioReal(t *testing.T) {
	casos := []struct {
		nombre   string
		cabecera []byte
		formato  string
	}{
		{"pista.flac", []byte("fLaC\x00\x00\x00\x22"), "flac"},
		{"pista.mp3", []byte("ID3\x03\x00\x00\x00"), "mp3"},
		{"pista.ogg", []byte("OggS\x00\x02"), "ogg"},
		{"pista.opus", []byte("OggS\x00\x02OpusHead"), "ogg"},
		{"pista.wav", []byte("RIFF\x24\x08\x00\x00WAVEfmt "), "wav"},
		{"pista.m4a", []byte("\x00\x00\x00\x20ftypM4A "), "mp4"},
		{"pista.webm", []byte{0x1A, 0x45, 0xDF, 0xA3, 0x01, 0x00}, "webm"},
		{"sin-etiqueta.mp3", []byte{0xFF, 0xFB, 0x90, 0x00}, "mp3"},
		{"pista.ape", []byte("MAC \x96\x0F"), "ape"},
		{"pista.wv", []byte("wvpk\x00\x00"), "wavpack"},
		{"pista.aiff", []byte("FORM\x00\x00\x10\x00AIFF"), "aiff"},
		{"pista.dsf", []byte("DSD \x00\x00\x00\x00"), "dsf"},
		// AMR empieza como un script; tiene que reconocerse ANTES del chequeo
		// de "#!" o se rechazaría audio legítimo.
		{"voz.amr", []byte("#!AMR\n"), "amr"},
	}
	for _, c := range casos {
		ruta := escribir(t, c.nombre, c.cabecera, 4096)
		v := Revisar(ruta)
		if !v.OK {
			t.Errorf("%s: debería aceptarse como audio (%s), se rechazó: %s", c.nombre, c.formato, v.Motivo)
			continue
		}
		if v.Formato != c.formato {
			t.Errorf("%s: formato %q, se esperaba %q", c.nombre, v.Formato, c.formato)
		}
	}
}

func TestRechazaEjecutablesYNombraElMotivo(t *testing.T) {
	casos := []struct {
		nombre   string
		archivo  string // con qué nombre se disfraza
		cabecera []byte
		enMotivo string
	}{
		{"exe disfrazado de flac", "pista.flac", []byte("MZ\x90\x00\x03"), "ejecutable de Windows"},
		{"elf disfrazado de mp3", "pista.mp3", append([]byte{0x7F, 'E', 'L', 'F'}, 0x02, 0x01, 0x01, 0x00), "ejecutable de Linux"},
		{"mach-o disfrazado de m4a", "pista.m4a", []byte{0xCF, 0xFA, 0xED, 0xFE, 0x07}, "macOS"},
		{"script disfrazado de ogg", "pista.ogg", []byte("#!/bin/sh\nrm -rf /\n"), "script"},
		{"zip disfrazado de flac", "pista.flac", []byte("PK\x03\x04\x14\x00"), "comprimido"},
		{"gzip disfrazado de wav", "pista.wav", []byte{0x1F, 0x8B, 0x08, 0x00}, "comprimido"},
		{"por si acaso .exe", "instalador.exe", []byte("MZ\x90\x00"), "Windows"},
		{"pdf disfrazado", "libro.flac", []byte("%PDF-1.7\n"), "PDF"},
		{"html servido como audio", "pista.mp3", []byte("<!DOCTYPE html><html>"), "página web"},
	}
	for _, c := range casos {
		ruta := escribir(t, c.archivo, c.cabecera, 4096)
		v := Revisar(ruta)
		if v.OK {
			t.Errorf("%s: NO debería aceptarse (formato detectado %q)", c.nombre, v.Formato)
			continue
		}
		if !strings.Contains(v.Motivo, c.enMotivo) {
			t.Errorf("%s: el motivo %q no menciona %q", c.nombre, v.Motivo, c.enMotivo)
		}
	}
}

// Lo desconocido también se rechaza: la lista es blanca, no negra. Si alguien
// inventa un formato nuevo, preferimos no descargarlo a adivinar.
func TestRechazaCabeceraDesconocida(t *testing.T) {
	ruta := escribir(t, "raro.flac", []byte{0x99, 0x88, 0x77, 0x66, 0x55, 0x44}, 4096)
	v := Revisar(ruta)
	if v.OK {
		t.Fatal("una cabecera desconocida no puede pasar como audio")
	}
	if !strings.Contains(v.Motivo, "ningún formato de audio") {
		t.Fatalf("motivo inesperado: %q", v.Motivo)
	}
}

func TestRechazaArchivosInservibles(t *testing.T) {
	// Un archivo vacío no es "audio sin datos", es una descarga fallida.
	if v := Revisar(escribir(t, "vacio.flac", nil, 0)); v.OK || !strings.Contains(v.Motivo, "demasiado chico") {
		t.Fatalf("un archivo vacío debe rechazarse: %+v", v)
	}
	// El "audio" de 20 bytes tampoco sirve para nada.
	if v := Revisar(escribir(t, "mini.flac", []byte("fLaC"), 20)); v.OK {
		t.Fatal("un archivo por debajo del mínimo no debe aceptarse")
	}
	// Un directorio no es un archivo.
	dir := t.TempDir()
	if v := Revisar(dir); v.OK || !strings.Contains(v.Motivo, "directorio") {
		t.Fatalf("un directorio debe rechazarse: %+v", v)
	}
	// Ruta inexistente: no debe entrar en pánico.
	if v := Revisar(filepath.Join(dir, "no-existe.flac")); v.OK {
		t.Fatal("una ruta inexistente no puede aceptarse")
	}
}

func TestHelpersPublicos(t *testing.T) {
	flac := escribir(t, "ok.flac", []byte("fLaC\x00\x00\x00\x22"), 2048)
	exe := escribir(t, "malo.flac", []byte("MZ\x90\x00\x03"), 2048)

	if !EsAudio(flac) {
		t.Error("EsAudio(flac) debe ser true")
	}
	if EsAudio(exe) {
		t.Error("EsAudio(exe) debe ser false")
	}
	if err := EsAudioErr(flac); err != nil {
		t.Errorf("EsAudioErr(flac) = %v, se esperaba nil", err)
	}
	if err := EsAudioErr(exe); err == nil || !strings.Contains(err.Error(), "audioguard") {
		t.Errorf("EsAudioErr(exe) debe explicar el rechazo, dio: %v", err)
	}
	// El tamaño reportado es el del archivo, para que el llamador pueda
	// compararlo con lo que esperaba recibir de la red.
	if v := Revisar(flac); v.Bytes != 2048 {
		t.Errorf("Bytes = %d, se esperaba 2048", v.Bytes)
	}
}
