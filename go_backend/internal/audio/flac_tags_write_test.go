package audio

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
)

// flacConEtiquetas arma un FLAC mínimo: STREAMINFO + comentarios + portada +
// "audio" (bytes irrelevantes: acá se prueba el rearmado del archivo, no el
// decodificador).
func flacConEtiquetas(entradas ...string) []byte {
	var out []byte
	out = append(out, []byte("fLaC")...)
	out = append(out, bloqueFLAC(0, false, streaminfo(44100, 8075682))...)
	out = append(out, bloqueFLAC(bloqueComentariosVorbis, false, comentariosVorbis(entradas...))...)
	out = append(out, bloqueFLAC(bloquePortada, true, []byte{0x00, 0x00, 0x00, 0x03, 'i', 'm', 'g'})...)
	return append(out, []byte("frames de audio (irrelevante)")...)
}

// Lo que arregla este escritor: antes usaba APE tags, así que un FLAC quedaba
// sin etiquetas legibles. Ahora se escriben comentarios Vorbis y se leen de
// vuelta con el lector real de la app.
func TestEscribirEtiquetasFLACSeLeeDevuelta(t *testing.T) {
	path := filepath.Join(t.TempDir(), "tema.flac")
	if err := os.WriteFile(path, flacConEtiquetas("ENCODER=lavc"), 0o644); err != nil {
		t.Fatal(err)
	}
	meta := &Metadata{
		Title: "NUEVAYoL", Artist: "Bad Bunny", Album: "DeBÍ TiRAR MáS FOToS",
		AlbumArtist: "Bad Bunny", Genre: "Reggaetón", ISRC: "qmfMF2447055",
		Year: 2025, TrackNumber: 1, TrackTotal: 17, DiscNumber: 1,
	}
	if err := WriteMetadata(path, meta); err != nil {
		t.Fatalf("no se pudo etiquetar: %v", err)
	}
	leido, err := ReadFileMetadata(path)
	if err != nil {
		t.Fatalf("el archivo quedó ilegible: %v", err)
	}
	if leido.Title != "NUEVAYoL" || leido.Artist != "Bad Bunny" {
		t.Errorf("título/artista no se leyeron: %+v", leido)
	}
	if leido.Album != "DeBÍ TiRAR MáS FOToS" || leido.AlbumArtist != "Bad Bunny" {
		t.Errorf("álbum/álbum-artista no se leyeron: album=%q aa=%q", leido.Album, leido.AlbumArtist)
	}
	if leido.ISRC != "QMFMF2447055" {
		t.Errorf("el ISRC debe normalizarse a mayúsculas: %q", leido.ISRC)
	}
	if leido.Genre != "Reggaetón" {
		t.Errorf("género perdido: %q", leido.Genre)
	}
	// El resto del archivo no se toca: portada y audio siguen ahí, en orden.
	crudo, _ := os.ReadFile(path)
	if !bytes.Contains(crudo, []byte("frames de audio (irrelevante)")) {
		t.Error("el audio se perdio al etiquetar")
	}
	if !leido.HasCover {
		t.Error("la portada incrustada se perdio al etiquetar")
	}
	if leido.SampleRate != 44100 {
		t.Errorf("el STREAMINFO se corrompio: sample rate %d", leido.SampleRate)
	}
	// Las etiquetas ajenas se conservan: no son nuestras.
	if !bytes.Contains(crudo, []byte("ENCODER=lavc")) {
		t.Error("una etiqueta que no gestionamos se borro")
	}
}

// Etiquetar dos veces no puede acumular bloques de comentarios ni duplicar
// entradas: es lo que dejaba el archivo con metadata inflada.
func TestEscribirEtiquetasFLACEsIdempotente(t *testing.T) {
	path := filepath.Join(t.TempDir(), "tema.flac")
	if err := os.WriteFile(path, flacConEtiquetas("TITLE=viejo"), 0o644); err != nil {
		t.Fatal(err)
	}
	meta := &Metadata{Title: "DtMF", Artist: "Bad Bunny"}
	for i := 0; i < 3; i++ {
		if err := WriteMetadata(path, meta); err != nil {
			t.Fatalf("intento %d: %v", i+1, err)
		}
	}
	crudo, _ := os.ReadFile(path)
	if n := bytes.Count(crudo, []byte("TITLE=DtMF")); n != 1 {
		t.Errorf("el título quedó %d veces; debe quedar una sola", n)
	}
	if bytes.Contains(crudo, []byte("TITLE=viejo")) {
		t.Error("el título viejo sobrevivió al reetiquetado")
	}
	if leido, err := ReadFileMetadata(path); err != nil || leido.Title != "DtMF" {
		t.Errorf("lectura tras reetiquetar: %+v err=%v", leido, err)
	}
}

// Separar artistas tiene que dejar VARIAS entradas ARTIST (así lo expresa el
// formato) sin perder el resto de las etiquetas.
func TestReescribirArtistasFLACConservaElResto(t *testing.T) {
	path := filepath.Join(t.TempDir(), "tema.flac")
	if err := os.WriteFile(path, flacConEtiquetas("TITLE=VeLDá", "ISRC=QMFMF2447055", "ARTIST=Bad Bunny"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := RewriteSplitArtistTags(path, []string{"Bad Bunny", "Omar Courtz"}, []string{"Bad Bunny"}); err != nil {
		t.Fatalf("no se pudieron separar los artistas: %v", err)
	}
	crudo, _ := os.ReadFile(path)
	// Se cuentan las ENTRADAS del bloque de comentarios, no las apariciones del
	// texto: "ALBUMARTIST=Bad Bunny" contiene "ARTIST=Bad Bunny" adentro.
	titular, invitado := 0, 0
	for _, e := range entradasDeComentarios(t, crudo) {
		switch e {
		case "ARTIST=Bad Bunny":
			titular++
		case "ARTIST=Omar Courtz":
			invitado++
		}
	}
	if titular != 1 {
		t.Errorf("el artista principal debe quedar como un solo ARTIST: %d", titular)
	}
	if invitado != 1 {
		t.Errorf("el segundo artista no entró (o se duplicó): %d", invitado)
	}
	if !bytes.Contains(crudo, []byte("TITLE=VeLDá")) {
		t.Error("el título se perdio al separar artistas (era el bug del escritor viejo)")
	}
	if !bytes.Contains(crudo, []byte("frames de audio (irrelevante)")) {
		t.Error("el audio se perdio al separar artistas")
	}
	if leido, err := ReadFileMetadata(path); err != nil || leido.Title != "VeLDá" {
		t.Errorf("lectura tras separar artistas: %+v err=%v", leido, err)
	}
}

// entradasDeComentarios lee del archivo real las entradas del bloque Vorbis,
// que es exactamente lo que ve cualquier reproductor.
func entradasDeComentarios(t *testing.T, crudo []byte) []string {
	t.Helper()
	bloques, _, previos, _, err := partirFLAC(crudo)
	if err != nil {
		t.Fatalf("no se pudo leer el FLAC: %v", err)
	}
	if len(bloques) != 2 {
		t.Fatalf("esperaba STREAMINFO + comentarios + portada, quedaron %d bloques sin comentarios", len(bloques))
	}
	return previos
}

// Un archivo que no es FLAC no se toca: mejor no etiquetar que corromper.
func TestEscribirEtiquetasFLACRechazaBasura(t *testing.T) {
	path := filepath.Join(t.TempDir(), "noflac.flac")
	if err := os.WriteFile(path, []byte("esto no es un FLAC"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := WriteMetadata(path, &Metadata{Title: "x"}); err == nil {
		t.Error("debería rechazar un archivo sin cabecera fLaC")
	}
	crudo, _ := os.ReadFile(path)
	if string(crudo) != "esto no es un FLAC" {
		t.Error("el archivo se modificó pese a no ser un FLAC")
	}
}
