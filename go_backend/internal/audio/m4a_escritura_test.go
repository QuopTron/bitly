package audio

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
)

// mp4DePrueba arma un MP4 mínimo pero VÁLIDO: ftyp + moov(mvhd + trak + udta) +
// mdat. Es la estructura que tienen los archivos que baja InnerTube/YouTube.
func mp4DePrueba(conUdta bool, conMeta bool) []byte {
	var moovContenido bytes.Buffer
	moovContenido.Write(armarCajaMP4("mvhd", make([]byte, 100)))
	moovContenido.Write(armarCajaMP4("trak", make([]byte, 200)))
	if conUdta {
		var udtaContenido bytes.Buffer
		if conMeta {
			udtaContenido.Write(armarMetaConItunes(nil))
		}
		moovContenido.Write(armarCajaMP4("udta", udtaContenido.Bytes()))
	}
	var f bytes.Buffer
	f.Write(armarCajaMP4("ftyp", []byte("M4A \x00\x00\x00\x00M4A mp42")))
	f.Write(armarCajaMP4("moov", moovContenido.Bytes()))
	f.Write(armarCajaMP4("mdat", make([]byte, 512)))
	return f.Bytes()
}

// verificarEstructura falla si el archivo dejó de ser un MP4 legible: el bug que
// se está previniendo producía mvhd/trak/udta sueltos al tope (sin la caja moov)
// y ningún reproductor podía abrir la canción.
func verificarEstructura(t *testing.T, data []byte) {
	t.Helper()
	cajas, ok := leerCajasMP4(data)
	if !ok {
		t.Fatal("el MP4 quedó con cajas ilegibles (bytes que no forman átomos)")
	}
	tipos := map[string]bool{}
	for _, c := range cajas {
		tipos[c.tipo] = true
	}
	if !tipos["moov"] {
		t.Fatal("falta la caja moov: el archivo no lo abre ningún reproductor")
	}
	if !tipos["ftyp"] || !tipos["mdat"] {
		t.Fatalf("faltan cajas base (ftyp/mdat): %v", tipos)
	}
}

// buscarAtomo recorre la ruta de cajas indicada y devuelve su contenido.
func buscarAtomo(t *testing.T, data []byte, ruta ...string) []byte {
	t.Helper()
	actual := data
	for _, tipo := range ruta {
		cajas, ok := leerCajasMP4(actual)
		if !ok {
			t.Fatalf("no se pudo recorrer buscando %q", tipo)
		}
		encontrado := false
		for _, c := range cajas {
			if c.tipo != tipo {
				continue
			}
			hijo := actual[c.inicio:c.fin]
			if len(hijo) < 8 {
				t.Fatalf("%q demasiado corto", tipo)
			}
			actual = hijo[8:]
			encontrado = true
			break
		}
		if !encontrado {
			t.Fatalf("no se encontró la caja %q", tipo)
		}
	}
	return actual
}

func TestWriteM4ATagsConservaEstructura(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "cancion.m4a")
	if err := os.WriteFile(path, mp4DePrueba(false, false), 0o600); err != nil {
		t.Fatal(err)
	}

	err := WriteM4AFreeformTags(path, map[string]string{
		"Title":  "NUEVAYoL",
		"Artist": "Bad Bunny",
		"Album":  "DeBÍ TiRAR MáS FOToS",
		"ISRC":   "QMFMF2447055",
	})
	if err != nil {
		t.Fatalf("WriteM4AFreeformTags: %v", err)
	}

	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	verificarEstructura(t, data)

	// Las etiquetas tienen que quedar leíbles en udta→meta→ilst, y con los
	// átomos de iTunes (sin el © ningún reproductor las muestra).
	ilst := buscarAtomo(t, data, "moov", "udta", "meta")
	if !bytes.Contains(ilst, []byte("\xa9nam")) {
		t.Error("falta el átomo de título (©nam)")
	}
	if !bytes.Contains(ilst, []byte("\xa9ART")) {
		t.Error("falta el átomo de artista (©ART)")
	}
	if !bytes.Contains(data, []byte("NUEVAYoL")) {
		t.Error("el título no quedó escrito en el archivo")
	}
	if !bytes.Contains(data, []byte("QMFMF2447055")) {
		t.Error("el ISRC no quedó escrito en el archivo")
	}
}

func TestWriteM4ATagsSobreArchivoConUdta(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "con_udta.m4a")
	if err := os.WriteFile(path, mp4DePrueba(true, true), 0o600); err != nil {
		t.Fatal(err)
	}

	if err := WriteM4AFreeformTags(path, map[string]string{"Title": "DtMF"}); err != nil {
		t.Fatalf("WriteM4AFreeformTags: %v", err)
	}
	data, _ := os.ReadFile(path)
	verificarEstructura(t, data)
	if !bytes.Contains(data, []byte("DtMF")) {
		t.Error("el título no se escribió en el archivo que ya tenía udta")
	}
}

func TestWriteMP4CoverConservaEstructura(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "con_portada.m4a")
	if err := os.WriteFile(path, mp4DePrueba(true, true), 0o600); err != nil {
		t.Fatal(err)
	}
	// JPEG mínimo (cabecera válida): alcanza para que se detecte el tipo.
	cover := append([]byte{0xFF, 0xD8, 0xFF, 0xE0}, make([]byte, 64)...)

	if err := writeMP4Cover(path, cover); err != nil {
		t.Fatalf("writeMP4Cover: %v", err)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	verificarEstructura(t, data)
	if !bytes.Contains(data, []byte("covr")) {
		t.Error("no se escribió el átomo covr")
	}
}
