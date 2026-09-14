package soulseek

import (
	"strings"
	"testing"
)

// El nombre del archivo lo elige un DESCONOCIDO en la red, así que se prueba
// que no pueda escapar de la carpeta de descargas. La extensión se conserva
// (con ella el filtro de audioguard decide mirando los bytes reales).
func TestNombreArchivoDescargaNoEscapaDeLaCarpeta(t *testing.T) {
	casos := []struct {
		descripcion string
		ruta        string
		ext         string
		quiero      string
	}{
		{
			"ruta normal de un par",
			`Music\Daft Punk\Discovery\01 - One More Time.flac`,
			"flac", "01 - One More Time.flac",
		},
		{
			"intento de salir con ..\\..\\",
			`..\..\..\Windows\System32\evil.exe`,
			"flac", "evil.exe.flac",
		},
		{
			"caracteres prohibidos en Windows",
			`Music\a:b*c?d|e.flac`,
			"flac", "a_b_c_d_e.flac",
		},
		{
			"bytes de control en el nombre",
			"tema\x00\x01oculto.flac",
			"flac", "temaoculto.flac",
		},
	}
	for _, c := range casos {
		archivo := ArchivoEncontrado{Ruta: c.ruta, Extension: c.ext}
		nombre := nombreArchivoDescarga(archivo)
		if nombre != c.quiero {
			t.Fatalf("%s: nombre = %q, se esperaba %q", c.descripcion, nombre, c.quiero)
		}
		if strings.ContainsAny(nombre, `/\`) {
			t.Fatalf("%s: el nombre %q conserva un separador de ruta", c.descripcion, nombre)
		}
		if strings.Contains(nombre, "..") {
			t.Fatalf("%s: el nombre %q conserva un componente de subida", c.descripcion, nombre)
		}
	}
}

// Sin extensión declarada igual se devuelve un nombre usable (y el filtro de
// bytes decide después, no la extensión).
func TestNombreArchivoDescargaSinExtension(t *testing.T) {
	nombre := nombreArchivoDescarga(ArchivoEncontrado{Ruta: `Music\Tema raro`})
	if nombre == "" {
		t.Fatal("un archivo sin extensión quedó con nombre vacío")
	}
	if strings.ContainsAny(nombre, `/\`) {
		t.Fatalf("el nombre %q conserva un separador de ruta", nombre)
	}
}
