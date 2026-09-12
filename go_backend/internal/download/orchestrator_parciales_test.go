package download

import (
	"bytes"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

// =========================================================================
// REGRESIÓN: la reanudación adoptaba el parcial de OTRA canción
// =========================================================================
//
// Síntoma que se veía en el celular: hay canciones que "arrancan desde la
// mitad". La causa era que la búsqueda de parciales tomaba CUALQUIER archivo
// dl-*<ext> de la carpeta de descargas y usaba su tamaño como offset del
// Range, así que el archivo final quedaba cosido: los bytes de una canción
// seguidos de la cola de otra.
//
// Estos tests fallan con la lógica vieja (adoptar cualquier dl-*) y pasan con
// la identidad por pista + fuente de orchestrator_parciales.go.

// fuenteConRango sirve [cuerpo] y responde 206 cuando le piden un rango.
func fuenteConRango(t *testing.T, cuerpo []byte) *httptest.Server {
	t.Helper()
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "audio/flac")
		w.Header().Set("Accept-Ranges", "bytes")
		rh := r.Header.Get("Range")
		if rh == "" {
			w.Header().Set("Content-Length", strconv.Itoa(len(cuerpo)))
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write(cuerpo)
			return
		}
		inicio, fin := int64(0), int64(len(cuerpo)-1)
		parte := strings.TrimPrefix(rh, "bytes=")
		trozos := strings.Split(parte, "-")
		if v, err := strconv.ParseInt(trozos[0], 10, 64); err == nil {
			inicio = v
		}
		if len(trozos) > 1 && trozos[1] != "" {
			if v, err := strconv.ParseInt(trozos[1], 10, 64); err == nil {
				fin = v
			}
		}
		if inicio >= int64(len(cuerpo)) {
			w.WriteHeader(http.StatusRequestedRangeNotSatisfiable)
			return
		}
		if fin > int64(len(cuerpo)-1) {
			fin = int64(len(cuerpo) - 1)
		}
		w.Header().Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", inicio, fin, len(cuerpo)))
		w.Header().Set("Content-Length", strconv.FormatInt(fin-inicio+1, 10))
		w.WriteHeader(http.StatusPartialContent)
		_, _ = w.Write(cuerpo[inicio : fin+1])
	}))
}

// TestReanudacionNoCoseDosAudios es el test del síntoma reportado.
func TestReanudacionNoCoseDosAudios(t *testing.T) {
	cuerpoA := bytes.Repeat([]byte("A"), 4000)
	cuerpoB := bytes.Repeat([]byte("B"), 4000)

	srv := fuenteConRango(t, cuerpoB)
	defer srv.Close()

	outDir := t.TempDir()

	// Parcial "de una descarga anterior" de OTRA pista y OTRA fuente.
	pistaAjena := sanitizarNombreArchivo("TRACK_A")
	huellaAjena := huellaFuente(srv.URL + "/a.flac")
	parcialAjeno := filepath.Join(outDir, prefijoParcial+pistaAjena+"-"+huellaAjena+"-1234.flac")
	if err := os.WriteFile(parcialAjeno, cuerpoA[:1200], 0644); err != nil {
		t.Fatal(err)
	}

	dest, err := descargarAArchivo(srv.URL+"/b.flac", outDir, Request{TrackID: "TRACK_B"}, "", "", func(int64, int64) {})
	if err != nil {
		t.Fatalf("descarga falló: %v", err)
	}

	// 1) El archivo final debe llamarse como la pista, no como el temporal.
	if filepath.Base(dest) != "TRACK_B.flac" {
		t.Fatalf("nombre final inesperado: %q (esperaba TRACK_B.flac)", filepath.Base(dest))
	}

	// 2) El contenido tiene que ser la canción B COMPLETA. Si se hubiera
	//    adoptado el parcial ajeno, acá habría 1200 bytes de A al principio.
	datos, err := os.ReadFile(dest)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(datos, cuerpoB) {
		t.Fatalf("el audio quedó cosido: %d bytes, primeros=%q (esperaba %d bytes de B)",
			len(datos), string(datos[:min(16, len(datos))]), len(cuerpoB))
	}
}

// TestBuscarParcialSoloDeLaMismaFuente cubre las tres variantes: mismo
// archivo se reanuda, otro archivo se ignora, y el temporal de la descarga
// paralela nunca se adopta.
func TestBuscarParcialSoloDeLaMismaFuente(t *testing.T) {
	dir := t.TempDir()
	pista := sanitizarNombreArchivo("TRACK_X")
	huella := huellaFuente("https://cdn.example.com/x.flac")
	huellaOtra := huellaFuente("https://otro.example.com/x.flac")

	propio := prefijoParcial + pista + "-" + huella + "-555.flac"
	ajeno := prefijoParcial + pista + "-" + huellaOtra + "-555.flac"
	paralelo := prefijoParalelo + pista + "-" + huella + "-555.flac"
	otraPista := prefijoParcial + "OTRA" + "-" + huella + "-555.flac"

	for _, nombre := range []string{ajeno, paralelo, otraPista} {
		if err := os.WriteFile(filepath.Join(dir, nombre), []byte("x"), 0644); err != nil {
			t.Fatal(err)
		}
	}
	if ruta, _ := buscarParcial(dir, pista, huella, ".flac"); ruta != "" {
		t.Fatalf("adoptó un parcial que no corresponde: %s", filepath.Base(ruta))
	}

	if err := os.WriteFile(filepath.Join(dir, propio), make([]byte, 777), 0644); err != nil {
		t.Fatal(err)
	}
	ruta, tam := buscarParcial(dir, pista, huella, ".flac")
	if filepath.Base(ruta) != propio {
		t.Fatalf("no encontró su propio parcial: %q", filepath.Base(ruta))
	}
	if tam != 777 {
		t.Fatalf("tamaño del parcial: %d (esperaba 777)", tam)
	}
}

// TestHuellaFuenteIgnoraLaFirma: la URL firmada cambia de query en cada
// petición, pero el audio es el mismo — la huella no debe cambiar, o la
// reanudación nunca funcionaría y quedarían parciales huérfanos.
func TestHuellaFuenteIgnoraLaFirma(t *testing.T) {
	a := huellaFuente("https://cdn.example.com/track.flac?token=AAA&exp=111")
	b := huellaFuente("https://cdn.example.com/track.flac?token=BBB&exp=222")
	if a != b {
		t.Fatalf("la firma cambió la huella: %s vs %s", a, b)
	}
	c := huellaFuente("https://otro.example.com/track.flac?token=AAA")
	if a == c {
		t.Fatal("hosts distintos no deberían compartir huella")
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
